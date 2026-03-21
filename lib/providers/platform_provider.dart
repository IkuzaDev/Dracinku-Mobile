import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class PlatformProvider extends ChangeNotifier {
  List<dynamic> _platforms = [];
  String _activePlatform = 'dramabox';
  String _activeLanguage = 'id';
  bool _isLoading = false;

  List<dynamic> get platforms => _platforms;
  String get activePlatform => _activePlatform;
  String get activeLanguage => _activeLanguage;
  bool get isLoading => _isLoading;

  String? get activePlatformName => _platforms.firstWhere(
    (p) => p['id'].toString() == _activePlatform,
    orElse: () => null,
  )?['name'];

  PlatformProvider() {
    _loadPrefs();
    _fetchPlatforms();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _activePlatform = prefs.getString('dw_platform') ?? 'dramabox';
    _activeLanguage = prefs.getString('dw_lang') ?? 'id';
    notifyListeners();
  }

  Future<void> fetchPlatforms() async {
    await _fetchPlatforms();
  }

  Future<void> _fetchPlatforms() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await ApiService.getToken();
      final res = (token != null && token.isNotEmpty) 
          ? await ApiService.userPlatforms() 
          : await ApiService.platforms();
          
      if (res.success && res.data != null && res.data is List) {
        _platforms = res.data;
        
        // If initial load and active platform is not in list, pick first available
        if (_platforms.isNotEmpty) {
          final exists = _platforms.any((p) => p['id'].toString() == _activePlatform);
          if (!exists) {
            _activePlatform = _platforms[0]['id'].toString();
          }
        }
      }
    } catch (e) {
      // Ignore
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> switchPlatform(String id) async {
    if (_activePlatform == id) return;
    
    _activePlatform = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dw_platform', id);
    notifyListeners();
    await _autoSwitchLanguage();
  }

  Future<void> switchLanguage(String lang) async {
    if (_activeLanguage == lang) return;
    
    _activeLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dw_lang', lang);
    notifyListeners();
  }

  Future<void> _autoSwitchLanguage() async {
    try {
      final res = await ApiService.languages(_activePlatform);
      if (res.success && res.data != null && res.data is List && res.data.isNotEmpty) {
        final List<dynamic> langs = res.data;
        
        // Try to keep CURRENT language if supported by new platform
        // Handle in vs id mapping for Indonesian
        String targetLang = _activeLanguage;
        if (targetLang == 'in') targetLang = 'id';
        
        bool found = false;
        for (var l in langs) {
          String code = l['code'].toString();
          if (code == _activeLanguage || (targetLang == 'id' && code == 'in')) {
            await switchLanguage(code);
            found = true;
            break;
          }
        }

        if (!found) {
          // If not found, pick first available
          final firstLangCode = langs[0]['code'];
          await switchLanguage(firstLangCode);
        }
      }
    } catch (e) {
      // Ignore
    }
  }
}
