import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/platform_provider.dart';
import '../theme/app_theme.dart';

class PlatformSwitcher extends StatelessWidget {
  const PlatformSwitcher({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const PlatformSwitcher(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final platformProv = Provider.of<PlatformProvider>(context);
    final platforms = platformProv.platforms;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SELECT PROVIDER',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (platformProv.isLoading)
            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else if (platforms.isEmpty)
            const Text('NO PROVIDERS AVAILABLE', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace'))
          else
            ListView.builder(
              shrinkWrap: true,
              itemCount: platforms.length,
              itemBuilder: (context, index) {
                final p = platforms[index];
                final isSelected = p['id'].toString() == platformProv.activePlatform;
                return ListTile(
                  title: Text(
                    p['name']?.toString().toUpperCase() ?? 'UNKNOWN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primary) : null,
                  onTap: () {
                    platformProv.switchPlatform(p['id'].toString());
                    Navigator.pop(context);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}
