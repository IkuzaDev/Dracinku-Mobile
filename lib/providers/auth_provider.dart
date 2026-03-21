import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  Map<String, dynamic>? _user;
  String? _token;
  bool _isLoading = false;

  Map<String, dynamic>? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null && _token!.isNotEmpty;
  bool get isAdmin => _user?['role'] == 'ADMIN';
  bool get isVip => _user?['is_vip_active'] == true || isAdmin;

  AuthProvider() {
    _loadUserFromPrefs();
  }

  Future<void> _loadUserFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('dw_token');
    final userStr = prefs.getString('dw_user');
    if (userStr != null) {
      _user = jsonDecode(userStr);
    }
    notifyListeners();

    if (_token != null) {
      refreshUser();
    }
  }

  Future<bool> login(String licenseKey) async {
    _isLoading = true;
    notifyListeners();

    try {
      final res = await ApiService.login(licenseKey);
      if (res.success && res.data != null) {
        _token = res.data!['token'];
        _user = res.data!['user'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dw_token', _token!);
        await prefs.setString('dw_user', jsonEncode(_user));
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await ApiService.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dw_token');
    await prefs.remove('dw_user');
    _token = null;
    _user = null;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_token == null) return;
    try {
      final res = await ApiService.me();
      if (res.success && res.data != null) {
        _user = res.data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dw_user', jsonEncode(_user));
        notifyListeners();
      }
    } catch (e) {
      // Handle error
    }
  }
}
