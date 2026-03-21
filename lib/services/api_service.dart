import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/api_response.dart';

class ApiService {
  static const String baseUrl = 'https://dracinku.site/api';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('dw_token');
  }

  static Future<Map<String, String>> _getHeaders() async {
    final token = await getToken();
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<ApiResponse<dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse('$baseUrl$path');
      final headers = await _getHeaders();
      http.Response response;

      switch (method) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(url, headers: headers, body: jsonEncode(body));
          break;
        case 'PUT':
          response = await http.put(url, headers: headers, body: jsonEncode(body));
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (response.statusCode == 401) {
        final data = jsonDecode(response.body);
        if (data['error']?['code'] == 'INVALID_TOKEN') {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('dw_token');
          await prefs.remove('dw_user');
          // Note: In Flutter, we should use a global navigator key or stream to redirect to login
        }
      }

      final jsonResponse = jsonDecode(response.body);
      return ApiResponse.fromJson(jsonResponse);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  // Auth Group
  static Future<ApiResponse> login(String licenseKey) =>
      _request('POST', '/auth/login', body: {'license_key': licenseKey});
  
  static Future<ApiResponse> googleLogin(String idToken) =>
      _request('POST', '/auth/google', body: {'id_token': idToken});
  
  static Future<ApiResponse> me() => _request('GET', '/auth/me');
  static Future<ApiResponse> logout() => _request('POST', '/auth/logout');

  // User Group
  static Future<ApiResponse> dashboard() => _request('GET', '/user/dashboard');
  static Future<ApiResponse> updateProfile(Map<String, dynamic> data) =>
      _request('PUT', '/user/profile', body: data);
  static Future<ApiResponse> saveHistory(Map<String, dynamic> data) =>
      _request('POST', '/user/history', body: data);
  static Future<ApiResponse> getHistory() => _request('GET', '/user/history');

  // Drama Group
  static Future<ApiResponse> platforms() => _request('GET', '/platforms');
  static Future<ApiResponse> userPlatforms() => _request('GET', '/user/platforms');
  static Future<ApiResponse> languages(String platform) =>
      _request('GET', '/drama/$platform/languages');
  static Future<ApiResponse> tablist(String platform, {String lang = 'id'}) =>
      _request('GET', '/drama/$platform/tablist?lang=$lang');
  static Future<ApiResponse> tabdata(String platform, Map<String, dynamic> body, {String lang = 'id'}) =>
      _request('POST', '/drama/$platform/tabdata?lang=$lang', body: body);
  static Future<ApiResponse> tabfeed(String platform, Map<String, dynamic> body, {String lang = 'id'}) =>
      _request('POST', '/drama/$platform/tabfeed?lang=$lang', body: body);
  static Future<ApiResponse> series(String platform, String id, {String lang = 'id', int quality = 720}) =>
      _request('GET', '/drama/$platform/series/$id?lang=$lang&quality=$quality');
  static Future<ApiResponse> search(String platform, Map<String, dynamic> body, {String lang = 'id'}) =>
      _request('POST', '/drama/$platform/search?lang=$lang', body: body);

  // Expose other groups as needed...
}
