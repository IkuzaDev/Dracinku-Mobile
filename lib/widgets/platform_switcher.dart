import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/platform_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';

const _surface = Color(0xFF18181B);
const _border  = Color(0xFF27272A);

class PlatformSwitcher extends StatelessWidget {
  const PlatformSwitcher({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const PlatformSwitcher(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prov      = Provider.of<PlatformProvider>(context);
    final platforms = prov.platforms.where((p) => p['is_active'] != false).toList();
    final bottom    = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F0F12),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: _border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha:0.15), borderRadius: BorderRadius.circular(2)),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Pilih Platform', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text('${platforms.length} platform tersedia', style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11)),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha:0.4), size: 20),
                ),
              ],
            ),
          ),

          Container(margin: const EdgeInsets.only(top: 12), height: 0.5, color: Colors.white.withValues(alpha:0.06)),

          // Grid
          if (prov.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
            )
          else if (platforms.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Text('Tidak ada platform', style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 13)),
            )
          else
            Padding(
              padding: const EdgeInsets.all(16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.9,
                ),
                itemCount: platforms.length,
                itemBuilder: (context, i) {
                  final p          = platforms[i] as Map;
                  final id         = p['id']?.toString() ?? '';
                  final name       = p['name']?.toString() ?? id;
                  final logo       = p['logo']?.toString() ?? '';
                  final isSelected = id == prov.activePlatform;

                  return GestureDetector(
                    onTap: () { prov.switchPlatform(id); Navigator.pop(context); },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha:0.09) : _surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isSelected ? Colors.white.withValues(alpha:0.2) : _border),
                      ),
                      child: Stack(
                        children: [
                          // Active dot
                          if (isSelected)
                            Positioned(
                              top: 8, right: 8,
                              child: Container(
                                width: 7, height: 7,
                                decoration: const BoxDecoration(color: Color(0xFF34D399), shape: BoxShape.circle),
                              ),
                            ),
                          Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                logo.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: 'https://dracinku.site$logo',
                                        width: 28, height: 28,
                                        fit: BoxFit.contain,
                                        placeholder: (context, url) => const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 1, color: Colors.white24)),
                                        errorWidget: (context, url, error) => Icon(Icons.apps_rounded, color: Colors.white.withValues(alpha: 0.2), size: 22),
                                      )
                                    : Icon(Icons.apps_rounded, color: Colors.white.withValues(alpha: 0.2), size: 22),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    name,
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.45),
                                      fontSize: 10,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          SizedBox(height: bottom + 8),
        ],
      ),
    );
  }
}