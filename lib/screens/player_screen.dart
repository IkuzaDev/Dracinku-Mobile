import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import '../providers/download_provider.dart';

// ── SRT cue model ─────────────────────────────────────────────────────────────
class _SrtCue {
  final Duration start;
  final Duration end;
  final String text;
  const _SrtCue({required this.start, required this.end, required this.text});
}

// ── SRT parser ────────────────────────────────────────────────────────────────
List<_SrtCue> _parseSrt(String raw) {
  final cues = <_SrtCue>[];
  final blocks = raw.replaceAll('\r\n', '\n').trim().split('\n\n');
  final timeRx = RegExp(
      r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})');

  for (final block in blocks) {
    final lines = block.trim().split('\n');
    for (int i = 0; i < lines.length; i++) {
      final m = timeRx.firstMatch(lines[i]);
      if (m != null) {
        final start = Duration(
            hours: int.parse(m[1]!),
            minutes: int.parse(m[2]!),
            seconds: int.parse(m[3]!),
            milliseconds: int.parse(m[4]!));
        final end = Duration(
            hours: int.parse(m[5]!),
            minutes: int.parse(m[6]!),
            seconds: int.parse(m[7]!),
            milliseconds: int.parse(m[8]!));
        final text = lines
            .sublist(i + 1)
            .join('\n')
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
        if (text.isNotEmpty) {
          cues.add(_SrtCue(start: start, end: end, text: text));
        }
        break;
      }
    }
  }
  return cues;
}

// ── Subtitle track info ───────────────────────────────────────────────────────
class _SubTrack {
  final String language;
  final String displayName;
  final String url;
  const _SubTrack(
      {required this.language,
      required this.displayName,
      required this.url});
}

// ── Video source type ─────────────────────────────────────────────────────────
enum _VideoType { mp4, hls, unknown }

_VideoType _detectVideoType(String url) {
  final lower = url.toLowerCase().split('?').first;
  if (lower.endsWith('.m3u8') || lower.contains('.m3u8')) return _VideoType.hls;
  if (lower.endsWith('.mp4') || lower.contains('.mp4')) return _VideoType.mp4;
  // Fallback: treat as mp4-compatible if no extension recognized
  return _VideoType.unknown;
}

// ── Colors ────────────────────────────────────────────────────────────────────
const _bg      = Color(0xFF0A0A0C);
const _surface = Color(0xFF18181B);
const _border  = Color(0xFF27272A);

// ── PlayerScreen ──────────────────────────────────────────────────────────────
class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> seriesData;
  final int initialEpisode;
  const PlayerScreen(
      {super.key,
      required this.seriesData,
      required this.initialEpisode});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _vpc;
  ChewieController?      _chewie;
  int  _epIndex      = 0;
  bool _initializing = false;
  bool _showEpSheet  = false;

  List<dynamic>   _episodes   = [];
  List<_SubTrack> _subTracks  = [];
  _SubTrack?      _activeSub;
  List<_SrtCue>   _cues       = [];
  String          _currentSub = '';
  bool            _subEnabled = true;
  bool            _subLoading = false;
  bool            _showSubMenu = false;

  // Current video info
  _VideoType _videoType = _VideoType.unknown;
  String     _errorMsg  = '';

  @override
  void initState() {
    super.initState();
    _epIndex  = widget.initialEpisode;
    _episodes = (widget.seriesData['chapters'] ??
        widget.seriesData['episodes'] ??
        widget.seriesData['episodeList'] ??
        []) as List;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _initPlayer();
  }

  @override
  void dispose() {
    _disposePlayer();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _disposePlayer() {
    _vpc?.removeListener(_onPositionChanged);
    _chewie?.dispose();
    _vpc?.dispose();
    _chewie = null;
    _vpc    = null;
  }

  // ── Build VideoPlayerController sesuai tipe URL ───────────────────────────
  VideoPlayerController _buildController(String url, _VideoType type) {
    final uri = Uri.parse(url);

    // Header umum untuk HLS — beberapa server membutuhkan ini
    const hlsHeaders = <String, String>{
      'Accept': '*/*',
      'Connection': 'keep-alive',
    };

    switch (type) {
      case _VideoType.hls:
        // video_player sudah mendukung HLS secara native di Android & iOS
        // melalui ExoPlayer (Android) dan AVPlayer (iOS)
        return VideoPlayerController.networkUrl(
          uri,
          httpHeaders: hlsHeaders,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );

      case _VideoType.mp4:
      case _VideoType.unknown:
      default:
        return VideoPlayerController.networkUrl(
          uri,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
        );
    }
  }

  // ── Init player ─────────────────────────────────────────────────────────────
  Future<void> _initPlayer() async {
    if (_episodes.isEmpty || _initializing) return;

    final ep  = _episodes[_epIndex] as Map<String, dynamic>;
    final url = ep['videoPath']?.toString() ??
        ep['realUrl']?.toString() ??
        ep['url']?.toString() ??
        '';

    if (url.isEmpty) {
      if (mounted) setState(() => _errorMsg = 'URL video tidak ditemukan.');
      return;
    }

    final type = _detectVideoType(url);

    if (mounted) {
      setState(() {
        _initializing = true;
        _cues         = [];
        _currentSub   = '';
        _errorMsg     = '';
        _videoType    = type;
      });
    }

    _disposePlayer();

    _subTracks = _parseSubTracks(ep);
    _activeSub = _subTracks.isNotEmpty ? _subTracks.first : null;

    final vpc = _buildController(url, type);

    try {
      await vpc.initialize();
    } catch (e) {
      if (mounted) {
        setState(() {
          _initializing = false;
          _errorMsg     = _friendlyError(e.toString(), type);
        });
      }
      vpc.dispose();
      return;
    }

    if (!mounted) {
      vpc.dispose();
      return;
    }

    vpc.addListener(_onPositionChanged);

    final chewie = ChewieController(
      videoPlayerController: vpc,
      autoPlay: true,
      looping: false,
      aspectRatio: vpc.value.aspectRatio,
      allowFullScreen: true,
      allowMuting: true,
      // Untuk HLS, buffer otomatis dihandle ExoPlayer/AVPlayer
      // Tidak perlu konfigurasi tambahan
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.white,
        handleColor: Colors.white,
        backgroundColor: Colors.white.withValues(alpha: 0.15),
        bufferedColor: Colors.white.withValues(alpha: 0.3),
      ),
    );

    setState(() {
      _vpc          = vpc;
      _chewie       = chewie;
      _initializing = false;
    });

    if (_activeSub != null) _loadSubtitle(_activeSub!);
  }

  // ── Pesan error yang ramah pengguna ──────────────────────────────────────
  String _friendlyError(String raw, _VideoType type) {
    if (raw.contains('403') || raw.contains('Forbidden')) {
      return 'Akses video ditolak (403). Server memblokir permintaan.';
    }
    if (raw.contains('404') || raw.contains('Not Found')) {
      return 'Video tidak ditemukan (404).';
    }
    if (raw.contains('SocketException') || raw.contains('Connection refused')) {
      return 'Tidak dapat terhubung ke server. Periksa koneksi internet.';
    }
    if (type == _VideoType.hls) {
      return 'Gagal memutar HLS stream. Format mungkin tidak didukung perangkat ini.';
    }
    return 'Gagal memuat video. Coba lagi.';
  }

  // ── Parse subtitle tracks ─────────────────────────────────────────────────
  List<_SubTrack> _parseSubTracks(Map<String, dynamic> ep) {
    final raw = ep['subtitle'];
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((s) => _SubTrack(
                language:    s['language']?.toString() ?? '',
                displayName: s['display_name']?.toString() ??
                    s['language']?.toString() ??
                    '',
                url: s['subtitle']?.toString() ?? '',
              ))
          .where((t) => t.url.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return [
        _SubTrack(language: 'default', displayName: 'Subtitle', url: raw)
      ];
    }
    return [];
  }

  // ── Fetch + parse SRT ─────────────────────────────────────────────────────
  Future<void> _loadSubtitle(_SubTrack track) async {
    if (mounted) {
      setState(() {
        _subLoading = true;
        _cues       = [];
        _currentSub = '';
      });
    }
    try {
      final res = await http
          .get(Uri.parse(track.url))
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final parsed = _parseSrt(res.body);
        setState(() {
          _cues       = parsed;
          _subLoading = false;
        });
      } else {
        if (mounted) setState(() => _subLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _subLoading = false);
    }
  }

  // ── Position listener — subtitle sync ─────────────────────────────────────
  void _onPositionChanged() {
    if (!_subEnabled || _cues.isEmpty || _vpc == null) {
      if (_currentSub.isNotEmpty && mounted) {
        setState(() => _currentSub = '');
      }
      return;
    }
    final pos = _vpc!.value.position;
    final cue = _cues.firstWhere(
      (c) => pos >= c.start && pos <= c.end,
      orElse: () =>
          _SrtCue(start: Duration.zero, end: Duration.zero, text: ''),
    );
    if (cue.text != _currentSub && mounted) {
      setState(() => _currentSub = cue.text);
    }
  }

  void _changeEpisode(int index) {
    if (index < 0 || index >= _episodes.length || index == _epIndex) return;
    _vpc?.removeListener(_onPositionChanged);
    setState(() {
      _epIndex    = index;
      _initializing = true;
      _cues       = [];
      _currentSub = '';
      _subTracks  = [];
      _errorMsg   = '';
    });
    _initPlayer();
  }

  void _switchSubtitle(_SubTrack? track) {
    setState(() {
      _activeSub   = track;
      _showSubMenu = false;
    });
    if (track != null) {
      _loadSubtitle(track);
    } else {
      setState(() {
        _cues       = [];
        _currentSub = '';
      });
    }
  }

  // ── Retry ────────────────────────────────────────────────────────────────
  void _retry() {
    setState(() { _errorMsg = ''; _initializing = true; });
    _initPlayer();
  }

  String get _epLabel {
    if (_episodes.isEmpty) return 'EP-${_epIndex + 1}';
    final ep = _episodes[_epIndex] as Map<String, dynamic>;
    return ep['eps']?.toString() ?? 'EP-${_epIndex + 1}';
  }

  String get _title {
    final book =
        widget.seriesData['book'] as Map<String, dynamic>? ?? widget.seriesData;
    return book['name']?.toString() ?? book['title']?.toString() ?? '';
  }

  bool get _isReady =>
      _chewie != null && (_vpc?.value.isInitialized ?? false) && !_initializing;

  void _showDownloadDialog(
      BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1C),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(message,
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopBar(),
              Expanded(
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // ── Video area ──────────────────────────────────────────
                    Center(
                      child: _errorMsg.isNotEmpty
                          ? _buildError()
                          : _isReady
                              ? Chewie(controller: _chewie!)
                              : _buildLoader(),
                    ),

                    // ── Badge tipe video (HLS/MP4) ──────────────────────────
                    if (_isReady)
                      Positioned(
                        top: 8, left: 8,
                        child: _VideoTypeBadge(type: _videoType),
                      ),

                    // ── Subtitle overlay ────────────────────────────────────
                    if (_subEnabled && _currentSub.isNotEmpty)
                      Positioned(
                        bottom: 48,
                        left: 24,
                        right: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _currentSub,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                              shadows: [
                                Shadow(color: Colors.black, blurRadius: 4)
                              ],
                            ),
                          ),
                        ),
                      ),

                    // ── Subtitle loading indicator ──────────────────────────
                    if (_subLoading)
                      Positioned(
                        bottom: 52,
                        right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: _surface,
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                  width: 10,
                                  height: 10,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      color: Colors.white54)),
                              const SizedBox(width: 6),
                              Text('Subtitle…',
                                  style: TextStyle(
                                      color:
                                          Colors.white.withValues(alpha: 0.4),
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),

          if (_showSubMenu) _buildSubMenu(),
          if (_showEpSheet) _buildEpisodeOverlay(),
        ],
      ),
    );
  }

  // ── Error widget ───────────────────────────────────────────────────────────
  Widget _buildError() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline_rounded,
            color: Colors.white38, size: 40),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            _errorMsg,
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: _retry,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: const Text('Coba Lagi',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top, left: 4, right: 12),
      color: Colors.black,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                Text(
                    '$_epLabel  ·  ${_epIndex + 1} / ${_episodes.length}',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 11)),
              ],
            ),
          ),

          // Subtitle button
          if (_subTracks.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() {
                _showSubMenu = !_showSubMenu;
                _showEpSheet = false;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _subEnabled
                      ? Colors.white.withValues(alpha: 0.12)
                      : _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _subEnabled
                          ? Colors.white.withValues(alpha: 0.25)
                          : _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.closed_caption_rounded,
                        color: _subEnabled
                            ? Colors.white
                            : Colors.white38,
                        size: 16),
                    const SizedBox(width: 5),
                    Text(
                      _activeSub?.displayName ?? 'CC',
                      style: TextStyle(
                          color: _subEnabled
                              ? Colors.white.withValues(alpha: 0.85)
                              : Colors.white38,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),

          // Download button
          Consumer<DownloadProvider>(
            builder: (context, dl, _) {
              final book =
                  widget.seriesData['book'] as Map<String, dynamic>? ??
                      widget.seriesData;
              final title = book['name']?.toString() ??
                  book['title']?.toString() ??
                  '';
              final taskTitle = '$title - Ep ${_epIndex + 1}';

              String? taskId;
              try {
                final item = dl.downloads
                    .firstWhere((d) => d['title'] == taskTitle);
                taskId = item['id'];
              } catch (_) {}

              final progress =
                  taskId != null ? dl.progress[taskId] : null;
              final status =
                  taskId != null ? dl.status[taskId] : null;
              final error =
                  taskId != null ? dl.errors[taskId] : null;
              final isDownloading =
                  status == DownloadTaskStatus.running ||
                      status == DownloadTaskStatus.enqueued;
              final isFailed =
                  status == DownloadTaskStatus.failed ||
                      status == DownloadTaskStatus.canceled;

              return GestureDetector(
                onTap: isDownloading
                    ? null
                    : () {
                        final ep = _episodes[_epIndex]
                            as Map<String, dynamic>;
                        final seriesId =
                            widget.seriesData['id']?.toString() ??
                                book['id']?.toString() ??
                                '';
                        final cover =
                            book['cover']?.toString() ??
                                book['image']?.toString() ??
                                '';
                        final video = ep['videoPath'] ??
                            ep['video_url'] ??
                            ep['url'] ??
                            '';
                        final sub = ep['subtitleUrl'] ??
                            ep['subtitle_url'] ??
                            ep['subtitle'] ??
                            ep['srt'];

                        final videoStr = video.toString();

                        // HLS tidak dapat didownload langsung
                        if (_detectVideoType(videoStr) ==
                            _VideoType.hls) {
                          _showDownloadDialog(context, 'Peringatan',
                              'HLS streaming tidak dapat didownload. Gunakan fitur streaming saja.');
                          return;
                        }

                        dl.downloadEpisode(
                          seriesId: seriesId,
                          title: taskTitle,
                          episodeIndex: _epIndex,
                          videoUrl: videoStr,
                          subtitleUrl: sub?.toString(),
                          coverUrl: cover,
                        );
                      },
                onLongPress: error != null
                    ? () {
                        _showDownloadDialog(context, 'Download Gagal', error);
                      }
                    : null,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: isDownloading
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: (progress ?? 0) / 100,
                                strokeWidth: 2.5,
                                color: Colors.white,
                                backgroundColor: Colors.white24,
                              ),
                              Text(
                                '${progress ?? 0}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 7,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        )
                      : isFailed
                          ? const Icon(Icons.error_outline,
                              color: Colors.redAccent, size: 20)
                          : const Icon(Icons.download_rounded,
                              color: Colors.white70, size: 20),
                ),
              );
            },
          ),

          // Episode list button
          GestureDetector(
            onTap: () => setState(() {
              _showEpSheet = !_showEpSheet;
              _showSubMenu = false;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.format_list_numbered_rounded,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 5),
                  Text('Episode',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subtitle menu ──────────────────────────────────────────────────────────
  Widget _buildSubMenu() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showSubMenu = false),
        child: Container(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 52,
                    right: 12),
                width: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFF111114),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      child: Text('Subtitle',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8)),
                    ),
                    Container(height: 0.5, color: _border),
                    _SubMenuItem(
                      label: 'Off',
                      selected: !_subEnabled,
                      onTap: () => setState(() {
                        _subEnabled  = false;
                        _showSubMenu = false;
                        _currentSub  = '';
                      }),
                    ),
                    ..._subTracks.map((t) => _SubMenuItem(
                          label: t.displayName,
                          selected: _subEnabled &&
                              _activeSub?.language == t.language,
                          onTap: () {
                            setState(() => _subEnabled = true);
                            _switchSubtitle(t);
                          },
                        )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Bottom bar ─────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final hasPrev = _epIndex > 0;
    final hasNext = _epIndex < _episodes.length - 1;
    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).padding.bottom + 8,
          top: 8),
      child: Row(
        children: [
          _NavBtn(
              label: 'Sebelumnya',
              icon: Icons.skip_previous_rounded,
              enabled: hasPrev,
              onTap: () => _changeEpisode(_epIndex - 1)),
          Expanded(
            child: Center(
              child: Text(_epLabel,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.2),
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          _NavBtn(
              label: 'Selanjutnya',
              icon: Icons.skip_next_rounded,
              enabled: hasNext,
              trailing: true,
              onTap: () => _changeEpisode(_epIndex + 1)),
        ],
      ),
    );
  }

  // ── Loading indicator ──────────────────────────────────────────────────────
  Widget _buildLoader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white54)),
        const SizedBox(height: 12),
        Text(
          _videoType == _VideoType.hls
              ? 'Memuat HLS stream…'
              : 'Memuat video…',
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.3), fontSize: 12),
        ),
      ],
    );
  }

  // ── Episode overlay ────────────────────────────────────────────────────────
  Widget _buildEpisodeOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showEpSheet = false),
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(context).size.height * 0.6),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F12),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                      margin: const EdgeInsets.only(top: 10),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                          color:
                              Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 14, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('Daftar Episode',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight:
                                          FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(
                                  '${_episodes.length} eps · $_title',
                                  style: TextStyle(
                                      color: Colors.white
                                          .withValues(alpha: 0.3),
                                      fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                            onPressed: () => setState(
                                () => _showEpSheet = false),
                            icon: Icon(Icons.close_rounded,
                                color: Colors.white
                                    .withValues(alpha: 0.4),
                                size: 20)),
                      ],
                    ),
                  ),
                  Container(
                      margin: const EdgeInsets.only(top: 10),
                      height: 0.5,
                      color: Colors.white.withValues(alpha: 0.06)),
                  Flexible(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 5,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                              childAspectRatio: 1),
                      itemCount: _episodes.length,
                      itemBuilder: (context, i) {
                        final isCurrent = i == _epIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() => _showEpSheet = false);
                            _changeEpisode(i);
                          },
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? Colors.white
                                  : _surface,
                              borderRadius:
                                  BorderRadius.circular(12),
                              border: Border.all(
                                  color: isCurrent
                                      ? Colors.white
                                      : _border),
                            ),
                            child: Center(
                              child: Text(
                                '${i + 1}',
                                style: TextStyle(
                                    color: isCurrent
                                        ? _bg
                                        : Colors.white
                                            .withValues(alpha: 0.5),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(
                      height:
                          MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Video type badge ───────────────────────────────────────────────────────────
class _VideoTypeBadge extends StatelessWidget {
  final _VideoType type;
  const _VideoTypeBadge({required this.type});

  @override
  Widget build(BuildContext context) {
    if (type == _VideoType.unknown) return const SizedBox.shrink();
    final isHls = type == _VideoType.hls;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isHls
            ? Colors.deepPurple.withValues(alpha: 0.75)
            : Colors.blueGrey.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        isHls ? 'HLS' : 'MP4',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── Sub-components ─────────────────────────────────────────────────────────────
class _SubMenuItem extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SubMenuItem(
      {required this.label,
      required this.selected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        color: Colors.transparent,
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: selected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.45),
                      fontSize: 13,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400)),
            ),
            if (selected)
              const Icon(Icons.check_rounded,
                  color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _NavBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled;
  final bool trailing;
  final VoidCallback onTap;
  const _NavBtn(
      {required this.label,
      required this.icon,
      required this.enabled,
      required this.onTap,
      this.trailing = false});

  @override
  Widget build(BuildContext context) {
    final c = enabled ? Colors.white : Colors.white.withValues(alpha: 0.2);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!trailing) ...[
          Icon(icon, color: c, size: 20),
          const SizedBox(width: 6)
        ],
        Text(label,
            style: TextStyle(
                color: c,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        if (trailing) ...[
          const SizedBox(width: 6),
          Icon(icon, color: c, size: 20)
        ],
      ]),
    );
  }
}