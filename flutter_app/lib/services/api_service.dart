import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';

/// Thrown when the backend returns success:false. Carries the message
/// and any field-level validation errors so screens can display them.
class ApiException implements Exception {
  final String message;
  final Map<String, dynamic>? errors;
  final int statusCode;
  ApiException(this.message, {this.errors, this.statusCode = 0});

  @override
  String toString() => message;
}

/// Central place for the backend base URL and every HTTP call the app makes.
///
/// IMPORTANT: change [baseUrl] to match where you deploy the `backend/`
/// folder. Defaults below assume XAMPP/WAMP running on the SAME machine as
/// the Android emulator:
///   - Android emulator  -> http://10.0.2.2/bookstore/backend/api
///   - Physical device   -> http://<your-pc-lan-ip>/bookstore/backend/api
///   - iOS simulator     -> http://localhost/bookstore/backend/api
class ApiService {
  static const String baseUrl = 'http://10.161.156.126/bookstore/backend/api';

  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Future<Map<String, String>> _headers() async {
    final token = await _getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Decodes the standard {success, message, data} envelope and throws
  /// ApiException when success is false, so callers just try/catch once.
  static dynamic _decode(http.Response res) {
    Map<String, dynamic> body;
    try {
      body = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Unexpected server response (HTTP ${res.statusCode}).');
    }

    if (body['success'] == true) {
      return body['data'];
    }
    throw ApiException(
      body['message'] ?? 'Something went wrong.',
      errors: body['data'] is Map<String, dynamic> ? body['data'] : null,
      statusCode: res.statusCode,
    );
  }

  static Future<dynamic> get(String path) async {
    final res = await http
        .get(Uri.parse('$baseUrl/$path'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  static Future<dynamic> post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(Uri.parse('$baseUrl/$path'),
            headers: await _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  static Future<dynamic> put(String path, Map<String, dynamic> body) async {
    final res = await http
        .put(Uri.parse('$baseUrl/$path'),
            headers: await _headers(), body: jsonEncode(body))
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  static Future<dynamic> delete(String path) async {
    final res = await http
        .delete(Uri.parse('$baseUrl/$path'), headers: await _headers())
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }
}
