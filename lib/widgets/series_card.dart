import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

class SeriesCard extends StatelessWidget {
  final Map<String, dynamic> series;
  final VoidCallback onTap;

  const SeriesCard({super.key, required this.series, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = series['title'] ?? series['name'] ?? 'Unknown';
    final coverUrl = series['cover'] ?? series['image'] ?? series['coverUrl'] ?? '';
    final chapterCount = series['chapterCount'] ?? 0;
    
    // Play count formatting logic
    final playCountRaw = series['playCount'];
    String playCountStr = '0';
    if (playCountRaw != null) {
      if (playCountRaw is String && RegExp(r'[a-zA-Z]').hasMatch(playCountRaw)) {
        playCountStr = playCountRaw;
      } else {
        num playCount = num.tryParse(playCountRaw.toString()) ?? 0;
        if (playCount >= 1000000000) {
          playCountStr = '${(playCount / 1000000000).toStringAsFixed(1)}B';
        } else if (playCount >= 1000000) {
          playCountStr = '${(playCount / 1000000).toStringAsFixed(1)}M';
        } else if (playCount >= 1000) {
          playCountStr = '${(playCount / 1000).toStringAsFixed(1)}K';
        } else {
          playCountStr = playCount.toString();
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.border),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: coverUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2),
                    ),
                    errorWidget: (context, url, error) => const Icon(Icons.error, color: AppTheme.textSecondary),
                  ),
                  
                  // Top left badge
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: const BoxDecoration(
                        color: Colors.black87,
                        border: Border(left: BorderSide(color: AppTheme.primary, width: 2)),
                      ),
                      child: Text(
                        series['badge'] ?? 'DRACINKU',
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                    ),
                  ),

                  // Bottom info bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black, Colors.transparent],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.play_arrow, color: AppTheme.primary, size: 12),
                              const SizedBox(width: 2),
                              Text(playCountStr, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            color: AppTheme.primary,
                            child: Text(
                              'EP $chapterCount',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2),
          ),
        ],
      ),
    );
  }
}
