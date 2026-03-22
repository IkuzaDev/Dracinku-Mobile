import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../providers/download_provider.dart';
import '../providers/platform_provider.dart';
import 'player_screen.dart';

class SeriesDetailScreen extends StatefulWidget {
  final String id;
  final String platform;

  const SeriesDetailScreen({super.key, required this.id, required this.platform});

  @override
  State<SeriesDetailScreen> createState() => _SeriesDetailScreenState();
}

class _SeriesDetailScreenState extends State<SeriesDetailScreen> {
  Map<String, dynamic>? _data;
  Map<String, dynamic>? _book;
  List<dynamic> _episodes = [];
  bool _isLoading = true;
  bool _descExpanded = false;
  bool _showEpisodeSheet = false;

  @override
  void initState() {
    super.initState();
    _loadSeries();
  }

  Future<void> _loadSeries() async {
    final prov = Provider.of<PlatformProvider>(context, listen: false);
    final res = await ApiService.series(widget.platform, widget.id, lang: prov.activeLanguage);
    if (!mounted) return;
    if (res.success && res.data != null) {
      setState(() {
        _data = res.data as Map<String, dynamic>;
        _book = (_data!['book'] ?? _data) as Map<String, dynamic>?;
        _episodes = (_data!['chapters'] ?? _data!['episodes'] ?? _data!['episodeList'] ?? []) as List;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _play(int index) {
    if (_data == null) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(seriesData: _data!, initialEpisode: index)));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0A0A0C),
        body: Center(
          child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)),
        ),
      );
    }

    if (_data == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0A0C),
        appBar: AppBar(backgroundColor: const Color(0xFF0A0A0C)),
        body: Center(child: Text('Gagal memuat data', style: TextStyle(color: Colors.white.withValues(alpha:0.4), fontSize: 14))),
      );
    }

    final title    = _book?['title'] ?? _book?['name'] ?? _data!['title'] ?? _data!['name'] ?? '';
    final cover    = _book?['cover'] ?? _book?['image'] ?? _book?['coverUrl'] ?? '';
    final synopsis = _book?['introduction'] ?? _book?['desc'] ?? _book?['description'] ?? '';
    final tags     = (_book?['tags'] as List?)?.cast<String>() ?? [];
    final playCount = _book?['playCount']?.toString();
    final chapterCount = _book?['chapterCount'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHero(cover, title),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      _buildTitle(title),
                      const SizedBox(height: 12),
                      _buildMeta(playCount, chapterCount, tags),
                      const SizedBox(height: 20),
                      _buildCTA(),
                      const SizedBox(height: 24),
                      if (synopsis.isNotEmpty) _buildSynopsis(synopsis),
                      const SizedBox(height: 24),
                      _buildEpisodeTrigger(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_showEpisodeSheet) _buildEpisodeSheet(title),
        ],
      ),
    );
  }

  Widget _buildHero(String cover, String title) {
    final screenH = MediaQuery.of(context).size.height;
    final heroH = (screenH * 0.42).clamp(240.0, 400.0);

    return SliverAppBar(
      expandedHeight: heroH,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0C),
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha:0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha:0.1), width: 1),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (cover.isNotEmpty)
              CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                placeholder: (_, _) => Container(color: const Color(0xFF18181B)),
                errorWidget: (context, url, error) => Container(color: const Color(0xFF18181B)),
                imageBuilder: (_, img) => Container(
                  decoration: BoxDecoration(image: DecorationImage(image: img, fit: BoxFit.cover)),
                  foregroundDecoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha:0.3), const Color(0xFF0A0A0C)],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),
              )
            else
              Container(color: const Color(0xFF18181B)),
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(height: 80, decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xFF0A0A0C), Colors.transparent],
                ),
              )),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 22,
        fontWeight: FontWeight.w900,
        height: 1.2,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildMeta(String? playCount, dynamic chapterCount, List<String> tags) {
    final chips = <_MetaChip>[];
    if (playCount != null) chips.add(_MetaChip(icon: Icons.star_rounded, label: playCount, iconColor: const Color(0xFFFBBF24)));
    if (chapterCount != null) chips.add(_MetaChip(label: '$chapterCount eps'));
    for (final t in tags.take(3)) {
      chips.add(_MetaChip(label: t, muted: true));
    }

    return Wrap(spacing: 6, runSpacing: 6, children: chips);
  }

  Widget _buildCTA() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _episodes.isNotEmpty ? () => _play(0) : null,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Mulai Menonton', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A0A0C),
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
        if (_episodes.length > 1) ...[
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => _play(_episodes.length - 1),
              icon: const Icon(Icons.skip_next_rounded, size: 20),
              label: const Text('Terakhir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha:0.12), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                backgroundColor: const Color(0xFF18181B),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSynopsis(String synopsis) {
    const maxLen = 180;
    final shortened = !_descExpanded && synopsis.length > maxLen;
    final displayText = shortened ? '${synopsis.substring(0, maxLen)}...' : synopsis;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionLabel(text: 'Sinopsis'),
        const SizedBox(height: 8),
        Text(displayText, style: TextStyle(color: Colors.white.withValues(alpha:0.5), fontSize: 13, height: 1.6)),
        if (synopsis.length > maxLen) ...[
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() => _descExpanded = !_descExpanded),
            child: Text(
              _descExpanded ? 'Tampilkan lebih sedikit ↑' : 'Baca selengkapnya ↓',
              style: TextStyle(color: Colors.white.withValues(alpha:0.35), fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEpisodeTrigger() {
    return GestureDetector(
      onTap: () => setState(() => _showEpisodeSheet = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha:0.08), width: 1),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha:0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.format_list_numbered_rounded, color: Colors.white.withValues(alpha:0.5), size: 18),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daftar Episode', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                Text('${_episodes.length} episodes tersedia', style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11)),
              ],
            ),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha:0.25), size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildEpisodeSheet(String seriesTitle) {
    return GestureDetector(
      onTap: () => setState(() => _showEpisodeSheet = false),
      child: Container(
        color: Colors.black.withValues(alpha:0.7),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.80),
              decoration: const BoxDecoration(
                color: Color(0xFF0F0F12),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: Color(0xFF27272A), width: 1)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 4, decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.15), borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Daftar Episode', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text('${_episodes.length} eps · $seriesTitle', style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _showEpisodeSheet = false),
                          icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha:0.4), size: 20),
                        ),
                      ],
                    ),
                  ),
                  Container(margin: const EdgeInsets.only(top: 12), height: 0.5, color: Colors.white.withValues(alpha:0.06)),
                  Flexible(
                    child: GridView.builder(
                      padding: const EdgeInsets.all(16),
                      shrinkWrap: true,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 1,
                      ),
                      itemCount: _episodes.length,
                      itemBuilder: (context, i) => _EpisodeCell(
                        index: i,
                        seriesId: widget.id,
                        episode: _episodes[i] as Map<String, dynamic>,
                        onTap: () { setState(() => _showEpisodeSheet = false); _play(i); },
                        onDownload: (ep) {
                          final dl = Provider.of<DownloadProvider>(context, listen: false);
                          final title = _book?['title'] ?? _book?['name'] ?? '';
                          final cover = _book?['cover'] ?? '';
                          final video = ep['videoPath'] ?? ep['video_url'] ?? ep['url'] ?? '';
                          final sub = ep['subtitleUrl'] ?? ep['subtitle_url'] ?? ep['subtitle'] ?? ep['srt'];
                          dl.downloadEpisode(seriesId: widget.id, title: '$title - Ep ${i + 1}', episodeIndex: i, videoUrl: video, subtitleUrl: sub, coverUrl: cover);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Download dimulai: Ep ${i + 1}'),
                              backgroundColor: const Color(0xFF18181B),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        },
                      ),
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

class _EpisodeCell extends StatelessWidget {
  final int index;
  final String seriesId;
  final Map<String, dynamic> episode;
  final VoidCallback onTap;
  final ValueChanged<Map<String, dynamic>> onDownload;

  const _EpisodeCell({required this.index, required this.seriesId, required this.episode, required this.onTap, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadProvider>(
      builder: (context, dl, _) {
        return FutureBuilder<bool>(
          future: dl.isDownloaded(seriesId, index),
          builder: (context, snap) {
            final downloaded = snap.data == true;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: downloaded ? Colors.white.withValues(alpha:0.08) : const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: downloaded ? Colors.white.withValues(alpha:0.2) : Colors.white.withValues(alpha:0.07),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: downloaded ? Colors.white : Colors.white.withValues(alpha:0.5),
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (downloaded)
                      Positioned(
                        top: 4, right: 4,
                        child: Icon(Icons.check_circle_rounded, size: 12, color: Colors.white.withValues(alpha:0.5)),
                      )
                    else
                      Positioned(
                        bottom: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => onDownload(episode),
                          child: Icon(Icons.download_rounded, size: 14, color: Colors.white.withValues(alpha:0.2)),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final bool muted;

  const _MetaChip({required this.label, this.icon, this.iconColor, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: muted ? Colors.white.withValues(alpha:0.03) : Colors.white.withValues(alpha:0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha:muted ? 0.05 : 0.08), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: iconColor ?? Colors.white.withValues(alpha:0.6)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: muted ? Colors.white.withValues(alpha:0.3) : Colors.white.withValues(alpha:0.65),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.4),
    );
  }
}