import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/api_service.dart';

/// Holds the current session (token + user) and exposes login/register/logout.
/// Persists the token so the user stays logged in between app launches.
class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _loading = false;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _loading;

  /// Called once at app startup to restore a saved session from local storage.
  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userJson = prefs.getString('auth_user');

    if (token == null || userJson == null) return;

    try {
      final map = Map<String, dynamic>.from(jsonDecode(userJson));
      _user = AppUser.fromJson(map);
      notifyListeners();
    } catch (_) {
      // Corrupt cache - ignore and require a fresh login.
    }
  }

  Future<void> login(String email, String password) async {
    _setLoading(true);
    try {
      final data = await ApiService.post('login.php', {
        'email': email,
        'password': password,
      });
      final token = data['token'] as String;
      _user = AppUser.fromJson(data['user']);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('auth_token', token);
      await prefs.setString('auth_user', jsonEncode(_user!.toJson()));
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> register(String fullName, String email, String password) async {
    _setLoading(true);
    try {
      await ApiService.post('register.php', {
        'full_name': fullName,
        'email': email,
        'password': password,
      });
      // Registration does not auto-login; the screen navigates back to Login.
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    try {
      await ApiService.post('logout.php', {});
    } catch (_) {
      // Even if the network call fails, clear the local session below.
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('auth_user');
    _user = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }
}
