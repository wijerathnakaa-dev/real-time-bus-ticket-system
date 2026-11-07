import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../../models/user_model.dart';

/// Login/registration against the Go API (JWT). The token is persisted so the
/// user stays signed in across app restarts.
class AuthService extends ChangeNotifier {
  static const _tokenKey = 'auth_token';
  final ApiClient _api = ApiClient.instance;

  UserModel? _currentUser;
  bool _isLoading = false;
  bool _restoring = true;
  String? _errorMessage;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isRestoring => _restoring;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;

  AuthService({bool restore = true}) {
    if (restore) {
      _restore();
    } else {
      _restoring = false;
    }
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      if (token != null) {
        _api.token = token;
        await refreshProfile();
      }
    } catch (_) {
      // Expired token or server unreachable: show the login screen.
      _api.token = null;
    }
    _restoring = false;
    notifyListeners();
  }

  /// Re-reads the profile (e.g. after an admin assigns a bus to this conductor).
  Future<void> refreshProfile() async {
    final me = await _api.get('/auth/me');
    _currentUser = UserModel.fromJson(me as Map<String, dynamic>);
    notifyListeners();
  }

  // Kept for screens written against the earlier API.
  Future<void> fetchUserData(String uid) => refreshProfile();

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String role,
    String? phone,
  }) =>
      _authenticate('/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
        'role': role,
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      });

  Future<bool> login({required String email, required String password}) =>
      _authenticate('/auth/login', {'email': email.trim(), 'password': password});

  Future<bool> _authenticate(String path, Map<String, dynamic> body) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final res = await _api.post(path, body) as Map<String, dynamic>;
      _api.token = res['token'] as String;
      _currentUser = UserModel.fromJson(res['user'] as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, _api.token!);
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Something went wrong: $e';
    }
    _setLoading(false);
    return false;
  }

  Future<void> logout() async {
    _api.token = null;
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
