import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import 'player_screen.dart';

const _bg      = Color(0xFF0A0A0C);
const _surface = Color(0xFF18181B);
const _border  = Color(0xFF27272A);

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Unduhan', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: _border),
        ),
      ),
      body: Consumer<DownloadProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)));
          }

          if (prov.downloads.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: _surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: Icon(Icons.download_for_offline_outlined, color: Colors.white.withOpacity(0.2), size: 32),
                  ),
                  const SizedBox(height: 16),
                  Text('Belum ada unduhan', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text('Episode yang diunduh akan muncul di sini', style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: prov.downloads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final item = prov.downloads[i] as Map<String, dynamic>;
              return _DownloadTile(
                item: item,
                onPlay: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PlayerScreen(
                    seriesData: {'chapters': item['episodes'] ?? [], 'book': {'name': item['title'] ?? ''}},
                    initialEpisode: item['episodeIndex'] as int? ?? 0,
                  )),
                ),
                onDelete: () async {
                  final confirmed = await _confirmDelete(context, item['title']?.toString() ?? 'episode ini');
                  if (confirmed && context.mounted) {
                    await prov.deleteDownload(item['id']);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: const Text('Unduhan dihapus'),
                        backgroundColor: _surface,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String title) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.delete_outline_rounded, color: Colors.red[400], size: 26),
              ),
              const SizedBox(height: 16),
              const Text('Hapus Unduhan?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '"$title" akan dihapus dari perangkat.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, false),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _border),
                        ),
                        child: const Center(child: Text('Batal', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx, true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Center(child: Text('Hapus', style: TextStyle(color: Colors.red[400], fontSize: 14, fontWeight: FontWeight.w700))),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ) ?? false;
  }
}

class _DownloadTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  const _DownloadTile({required this.item, required this.onPlay, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final title     = item['title']?.toString() ?? 'Untitled';
    final epName    = item['episodeName']?.toString() ?? 'Episode ${(item['episodeIndex'] as int? ?? 0) + 1}';
    final coverUrl  = item['coverUrl']?.toString() ?? item['cover']?.toString() ?? '';
    final filePath  = item['filePath']?.toString() ?? '';
    final hasFile   = filePath.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          // Thumbnail
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(15)),
            child: SizedBox(
              width: 80, height: 80,
              child: coverUrl.isNotEmpty
                  ? Image.network(coverUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbPlaceholder())
                  : _thumbPlaceholder(),
            ),
          ),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 3),
                  Text(epName, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: hasFile ? const Color(0xFF10B981).withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: hasFile ? const Color(0xFF34D399).withOpacity(0.3) : Colors.orange.withOpacity(0.3)),
                        ),
                        child: Text(
                          hasFile ? 'Tersimpan' : 'Tidak ditemukan',
                          style: TextStyle(
                            color: hasFile ? const Color(0xFF34D399) : Colors.orange,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Actions
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionBtn(icon: Icons.play_arrow_rounded, color: Colors.white, onTap: onPlay),
                const SizedBox(height: 4),
                _ActionBtn(icon: Icons.delete_outline_rounded, color: Colors.red.shade400, onTap: onDelete),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbPlaceholder() {
    return Container(
      color: const Color(0xFF111114),
      child: Icon(Icons.movie_outlined, color: Colors.white.withOpacity(0.15), size: 28),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.15)),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}