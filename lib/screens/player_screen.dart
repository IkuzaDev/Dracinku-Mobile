import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
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
  final timeRx = RegExp(r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})');

  for (final block in blocks) {
    final lines = block.trim().split('\n');
    for (int i = 0; i < lines.length; i++) {
      final m = timeRx.firstMatch(lines[i]);
      if (m != null) {
        final start = Duration(hours: int.parse(m[1]!), minutes: int.parse(m[2]!), seconds: int.parse(m[3]!), milliseconds: int.parse(m[4]!));
        final end   = Duration(hours: int.parse(m[5]!), minutes: int.parse(m[6]!), seconds: int.parse(m[7]!), milliseconds: int.parse(m[8]!));
        final text  = lines.sublist(i + 1).join('\n').replaceAll(RegExp(r'<[^>]+>'), '').trim();
        if (text.isNotEmpty) cues.add(_SrtCue(start: start, end: end, text: text));
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
  const _SubTrack({required this.language, required this.displayName, required this.url});
}

// ── Colors ────────────────────────────────────────────────────────────────────
const _bg      = Color(0xFF0A0A0C);
const _surface = Color(0xFF18181B);
const _border  = Color(0xFF27272A);

// ── PlayerScreen ──────────────────────────────────────────────────────────────
class PlayerScreen extends StatefulWidget {
  final Map<String, dynamic> seriesData;
  final int initialEpisode;
  const PlayerScreen({super.key, required this.seriesData, required this.initialEpisode});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _vpc;
  ChewieController?      _chewie;
  int  _epIndex = 0;
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

  @override
  void initState() {
    super.initState();
    _epIndex  = widget.initialEpisode;
    _episodes = (widget.seriesData['chapters'] ?? widget.seriesData['episodes'] ?? widget.seriesData['episodeList'] ?? []) as List;
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight, DeviceOrientation.portraitUp]);
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
    _chewie?.dispose(); _vpc?.dispose();
    _chewie = null; _vpc = null;
  }

  // ── Init player ─────────────────────────────────────────────────────────────
  Future<void> _initPlayer() async {
    if (_episodes.isEmpty || _initializing) return;
    final ep  = _episodes[_epIndex] as Map<String, dynamic>;
    final url = ep['videoPath']?.toString() ?? ep['realUrl']?.toString() ?? ep['url']?.toString() ?? '';
    if (url.isEmpty) return;

    if (mounted) setState(() { _initializing = true; _cues = []; _currentSub = ''; });
    _disposePlayer();

    // Parse subtitle tracks from episode
    _subTracks = _parseSubTracks(ep);
    _activeSub = _subTracks.isNotEmpty ? _subTracks.first : null;

    final vpc = VideoPlayerController.networkUrl(Uri.parse(url));
    try { await vpc.initialize(); } catch (_) {
      if (mounted) setState(() => _initializing = false);
      vpc.dispose(); return;
    }
    if (!mounted) { vpc.dispose(); return; }

    // Listen to position for subtitle sync
    vpc.addListener(_onPositionChanged);

    final chewie = ChewieController(
      videoPlayerController: vpc,
      autoPlay: true,
      looping: false,
      aspectRatio: vpc.value.aspectRatio,
      allowFullScreen: true,
      allowMuting: true,
      materialProgressColors: ChewieProgressColors(
        playedColor: Colors.white,
        handleColor: Colors.white,
        backgroundColor: Colors.white.withOpacity(0.15),
        bufferedColor: Colors.white.withOpacity(0.3),
      ),
    );

    setState(() { _vpc = vpc; _chewie = chewie; _initializing = false; });

    if (_activeSub != null) _loadSubtitle(_activeSub!);
  }

  // ── Parse subtitle tracks from episode data ──────────────────────────────
  List<_SubTrack> _parseSubTracks(Map<String, dynamic> ep) {
    final raw = ep['subtitle'];
    if (raw == null) return [];
    if (raw is List) {
      return raw.whereType<Map>().map((s) => _SubTrack(
        language:    s['language']?.toString() ?? '',
        displayName: s['display_name']?.toString() ?? s['language']?.toString() ?? '',
        url:         s['subtitle']?.toString() ?? '',
      )).where((t) => t.url.isNotEmpty).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return [_SubTrack(language: 'default', displayName: 'Subtitle', url: raw)];
    }
    return [];
  }

  // ── Fetch + parse SRT ────────────────────────────────────────────────────
  Future<void> _loadSubtitle(_SubTrack track) async {
    if (mounted) setState(() { _subLoading = true; _cues = []; _currentSub = ''; });
    try {
      final res = await http.get(Uri.parse(track.url)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && mounted) {
        final parsed = _parseSrt(res.body);
        setState(() { _cues = parsed; _subLoading = false; });
      } else {
        if (mounted) setState(() => _subLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _subLoading = false);
    }
  }

  // ── Position listener — finds matching cue ───────────────────────────────
  void _onPositionChanged() {
    if (!_subEnabled || _cues.isEmpty || _vpc == null) {
      if (_currentSub.isNotEmpty && mounted) setState(() => _currentSub = '');
      return;
    }
    final pos = _vpc!.value.position;
    final cue = _cues.firstWhere(
      (c) => pos >= c.start && pos <= c.end,
      orElse: () => _SrtCue(start: Duration.zero, end: Duration.zero, text: ''),
    );
    if (cue.text != _currentSub && mounted) setState(() => _currentSub = cue.text);
  }

  void _changeEpisode(int index) {
    if (index < 0 || index >= _episodes.length || index == _epIndex) return;
    _vpc?.removeListener(_onPositionChanged);
    setState(() { _epIndex = index; _initializing = true; _cues = []; _currentSub = ''; _subTracks = []; });
    _initPlayer();
  }

  void _switchSubtitle(_SubTrack? track) {
    setState(() { _activeSub = track; _showSubMenu = false; });
    if (track != null) _loadSubtitle(track);
    else setState(() { _cues = []; _currentSub = ''; });
  }

  String get _epLabel {
    if (_episodes.isEmpty) return 'EP-${_epIndex + 1}';
    final ep = _episodes[_epIndex] as Map<String, dynamic>;
    return ep['eps']?.toString() ?? 'EP-${_epIndex + 1}';
  }

  String get _title {
    final book = widget.seriesData['book'] as Map<String, dynamic>? ?? widget.seriesData;
    return book['name']?.toString() ?? book['title']?.toString() ?? '';
  }

  bool get _isReady => _chewie != null && (_vpc?.value.isInitialized ?? false);

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
                    Center(child: _isReady ? Chewie(controller: _chewie!) : _buildLoader()),
                    // Subtitle overlay
                    if (_subEnabled && _currentSub.isNotEmpty)
                      Positioned(
                        bottom: 48,
                        left: 24, right: 24,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
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
                              shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                            ),
                          ),
                        ),
                      ),
                    // Loading subtitle indicator
                    if (_subLoading)
                      Positioned(
                        bottom: 52, right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white54)),
                              const SizedBox(width: 6),
                              Text('Subtitle…', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
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

          // Subtitle language picker
          if (_showSubMenu) _buildSubMenu(),

          // Episode sheet
          if (_showEpSheet) _buildEpisodeOverlay(),
        ],
      ),
    );
  }

  // ── Top bar ────────────────────────────────────────────────────────────────
  Widget _buildTopBar() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top, left: 4, right: 12),
      color: Colors.black,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('$_epLabel  ·  ${_epIndex + 1} / ${_episodes.length}', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
              ],
            ),
          ),

          // Subtitle button
          if (_subTracks.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() { _showSubMenu = !_showSubMenu; _showEpSheet = false; }),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _subEnabled ? Colors.white.withOpacity(0.12) : _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _subEnabled ? Colors.white.withOpacity(0.25) : _border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.closed_caption_rounded, color: _subEnabled ? Colors.white : Colors.white38, size: 16),
                    const SizedBox(width: 5),
                    Text(
                      _activeSub?.displayName ?? 'CC',
                      style: TextStyle(color: _subEnabled ? Colors.white.withOpacity(0.85) : Colors.white38, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          
          // Download button
          IconButton(
            onPressed: () {
              final dl = Provider.of<DownloadProvider>(context, listen: false);
              final ep = _episodes[_epIndex] as Map<String, dynamic>;
              final book = widget.seriesData['book'] as Map<String, dynamic>? ?? widget.seriesData;
              final seriesId = widget.seriesData['id']?.toString() ?? book['id']?.toString() ?? '';
              final title = book['name']?.toString() ?? book['title']?.toString() ?? '';
              final cover = book['cover']?.toString() ?? book['image']?.toString() ?? '';
              final video = ep['videoPath'] ?? ep['video_url'] ?? ep['url'] ?? '';
              final sub = ep['subtitleUrl'] ?? ep['subtitle_url'] ?? ep['subtitle'] ?? ep['srt'];
              
              dl.downloadEpisode(
                seriesId: seriesId,
                title: '$title - Ep ${_epIndex + 1}',
                episodeIndex: _epIndex,
                videoUrl: video.toString(),
                subtitleUrl: sub?.toString(),
                coverUrl: cover,
              );
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Download dimulai: Ep ${_epIndex + 1}'),
                  backgroundColor: const Color(0xFF18181B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
            icon: const Icon(Icons.download_rounded, color: Colors.white70, size: 20),
          ),

          // Episode list button
          GestureDetector(
            onTap: () => setState(() { _showEpSheet = !_showEpSheet; _showSubMenu = false; }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _surface, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.format_list_numbered_rounded, color: Colors.white70, size: 16),
                  const SizedBox(width: 5),
                  Text('Episode', style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Subtitle language menu ─────────────────────────────────────────────────
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
                margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 52, right: 12),
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
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                      child: Text('Subtitle', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
                    ),
                    Container(height: 0.5, color: _border),
                    // Off option
                    _SubMenuItem(
                      label: 'Off',
                      selected: !_subEnabled,
                      onTap: () => setState(() { _subEnabled = false; _showSubMenu = false; _currentSub = ''; }),
                    ),
                    // Language tracks
                    ..._subTracks.map((t) => _SubMenuItem(
                      label: t.displayName,
                      selected: _subEnabled && _activeSub?.language == t.language,
                      onTap: () { setState(() => _subEnabled = true); _switchSubtitle(t); },
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
      padding: EdgeInsets.only(left: 16, right: 16, bottom: MediaQuery.of(context).padding.bottom + 8, top: 8),
      child: Row(
        children: [
          _NavBtn(label: 'Sebelumnya', icon: Icons.skip_previous_rounded, enabled: hasPrev, onTap: () => _changeEpisode(_epIndex - 1)),
          Expanded(child: Center(child: Text(_epLabel, style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, fontWeight: FontWeight.w700)))),
          _NavBtn(label: 'Selanjutnya', icon: Icons.skip_next_rounded, enabled: hasNext, trailing: true, onTap: () => _changeEpisode(_epIndex + 1)),
        ],
      ),
    );
  }

  // ── Loading indicator ──────────────────────────────────────────────────────
  Widget _buildLoader() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
      const SizedBox(height: 12),
      Text('Memuat video…', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12)),
    ]);
  }

  // ── Episode overlay ────────────────────────────────────────────────────────
  Widget _buildEpisodeOverlay() {
    return GestureDetector(
      onTap: () => setState(() => _showEpSheet = false),
      child: Container(
        color: Colors.black.withOpacity(0.65),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F12),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: _border)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 0),
                    child: Row(
                      children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Daftar Episode', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 2),
                          Text('${_episodes.length} eps · $_title', style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                        IconButton(onPressed: () => setState(() => _showEpSheet = false), icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.4), size: 20)),
                      ],
                    ),
                  ),
                  Container(margin: const EdgeInsets.only(top: 10), height: 0.5, color: Colors.white.withOpacity(0.06)),
                  Flexible(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 5, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1),
                      itemCount: _episodes.length,
                      itemBuilder: (context, i) {
                        final isCurrent = i == _epIndex;
                        return GestureDetector(
                          onTap: () { setState(() => _showEpSheet = false); _changeEpisode(i); },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            decoration: BoxDecoration(
                              color: isCurrent ? Colors.white : _surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isCurrent ? Colors.white : _border),
                            ),
                            child: Center(child: Text('${i + 1}', style: TextStyle(color: isCurrent ? _bg : Colors.white.withOpacity(0.5), fontSize: 14, fontWeight: FontWeight.w900))),
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                ],
              ),
            ),
          ),
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
  const _SubMenuItem({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        color: Colors.transparent,
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(color: selected ? Colors.white : Colors.white.withOpacity(0.45), fontSize: 13, fontWeight: selected ? FontWeight.w700 : FontWeight.w400))),
            if (selected) const Icon(Icons.check_rounded, color: Colors.white, size: 16),
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
  const _NavBtn({required this.label, required this.icon, required this.enabled, required this.onTap, this.trailing = false});

  @override
  Widget build(BuildContext context) {
    final c = enabled ? Colors.white : Colors.white.withOpacity(0.2);
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (!trailing) ...[Icon(icon, color: c, size: 20), const SizedBox(width: 6)],
        Text(label, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w600)),
        if (trailing) ...[const SizedBox(width: 6), Icon(icon, color: c, size: 20)],
      ]),
    );
  }
}