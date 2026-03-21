import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/platform_provider.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class LanguageSwitcher extends StatefulWidget {
  const LanguageSwitcher({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const LanguageSwitcher(),
    );
  }

  @override
  State<LanguageSwitcher> createState() => _LanguageSwitcherState();
}

class _LanguageSwitcherState extends State<LanguageSwitcher> {
  List<dynamic> _languages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLanguages();
  }

  Future<void> _loadLanguages() async {
    final platformProv = Provider.of<PlatformProvider>(context, listen: false);
    final res = await ApiService.languages(platformProv.activePlatform);
    if (mounted) {
      if (res.success && res.data != null) {
        setState(() {
          _languages = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final platformProv = Provider.of<PlatformProvider>(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'SELECT LANGUAGE',
            style: TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: AppTheme.primary))
          else if (_languages.isEmpty)
            const Text('NO LANGUAGES DETECTED', style: TextStyle(color: AppTheme.textSecondary, fontFamily: 'monospace'))
          else
            ListView.builder(
              shrinkWrap: true,
              itemCount: _languages.length,
              itemBuilder: (context, index) {
                final lang = _languages[index];
                final isSelected = lang['code'] == platformProv.activeLanguage;
                return ListTile(
                  subtitle: Text(lang['code'].toString().toUpperCase(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
                  title: Text(
                    lang['name']?.toString().toUpperCase() ?? 'UNKNOWN',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    ),
                  ),
                  trailing: isSelected ? const Icon(Icons.check, color: AppTheme.primary) : null,
                  onTap: () {
                    platformProv.switchLanguage(lang['code']);
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
