import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/platform_provider.dart';
import '../services/api_service.dart';

const _surface = Color(0xFF18181B);
const _border  = Color(0xFF27272A);

class LanguageSwitcher extends StatefulWidget {
  const LanguageSwitcher({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const LanguageSwitcher(),
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
    _load();
  }

  Future<void> _load() async {
    final prov = Provider.of<PlatformProvider>(context, listen: false);
    final res  = await ApiService.languages(prov.activePlatform);
    if (!mounted) return;
    setState(() {
      _languages = (res.success && res.data is List) ? res.data as List : [];
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prov   = Provider.of<PlatformProvider>(context);
    final bottom = MediaQuery.of(context).padding.bottom;

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
                      const Text('Pilih Bahasa', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        _isLoading ? 'Memuat…' : '${_languages.length} bahasa tersedia',
                        style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 11),
                      ),
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

          // Content
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white38)),
            )
          else if (_languages.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.language_rounded, color: Colors.white.withValues(alpha:0.15), size: 32),
                  const SizedBox(height: 10),
                  Text('Tidak ada bahasa tersedia', style: TextStyle(color: Colors.white.withValues(alpha:0.3), fontSize: 13)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: _languages.length,
                itemBuilder: (context, i) {
                  final lang       = _languages[i] as Map;
                  final code       = lang['code']?.toString() ?? '';
                  final name       = lang['name']?.toString() ?? code;
                  final isSelected = code == prov.activeLanguage;

                  return GestureDetector(
                    onTap: () {
                      prov.switchLanguage(code);
                      Navigator.pop(context);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.white.withValues(alpha:0.07) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? Colors.white.withValues(alpha:0.15) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Language code badge
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white.withValues(alpha:0.1) : _surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: isSelected ? Colors.white.withValues(alpha:0.2) : _border),
                            ),
                            child: Center(
                              child: Text(
                                code.substring(0, code.length.clamp(0, 2)).toUpperCase(),
                                style: TextStyle(
                                  color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.4),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white.withValues(alpha:0.55),
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          SizedBox(height: bottom + 12),
        ],
      ),
    );
  }
}