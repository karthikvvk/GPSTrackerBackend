import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/settings.dart';

/// Email/Password authentication service using Python backend
class AuthService {
  static String? _baseUrl;
  
  static Future<String> get baseUrl async {
    if (_baseUrl == null) {
      final settings = await Settings.instance;
      _baseUrl = settings.backendUrl;
    }
    return _baseUrl!;
  }
  
  static const String _userIdKey = 'user_id';
  static const String _emailKey = 'user_email';
  static const String _displayNameKey = 'user_display_name';
  static const String _roleKey = 'user_role';

  final http.Client _client;
  SharedPreferences? _prefs;

  // Cached user data
  String? _userId;
  String? _email;
  String? _displayName;
  String? _role;

  AuthService({http.Client? client}) : _client = client ?? http.Client();

  /// Initialize and load cached user data
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _userId = _prefs?.getString(_userIdKey);
    _email = _prefs?.getString(_emailKey);
    _displayName = _prefs?.getString(_displayNameKey);
    _role = _prefs?.getString(_roleKey);
  }

  /// Get current user ID
  String? get userId => _userId;

  /// Get display name
  String? get displayName => _displayName;

  /// Get email
  String? get email => _email;

  /// Get role
  String? get role => _role;

  /// Check if user is signed in
  bool get isSignedIn => _userId != null && _userId!.isNotEmpty;

  /// Register a new user
  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final url = await baseUrl;
      final response = await _client.post(
        Uri.parse('$url/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'display_name': displayName,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final user = data['user'];
        await _saveUserData(user);
        return user;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Registration failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Login with email and password
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    try {
      final url = await baseUrl;
      final response = await _client.post(
        Uri.parse('$url/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final user = data['user'];
        await _saveUserData(user);
        return user;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Login failed');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Update user role
  Future<void> updateRole(String role) async {
    if (_userId == null) return;

    try {
      final url = await baseUrl;
      final response = await _client.put(
        Uri.parse('$url/auth/profile'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': _userId,
          'role': role,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _role = role;
        await _prefs?.setString(_roleKey, role);
      }
    } catch (e) {
      // Ignore errors, role is stored locally anyway
      _role = role;
      await _prefs?.setString(_roleKey, role);
    }
  }

  /// Save user data to SharedPreferences
  Future<void> _saveUserData(Map<String, dynamic> user) async {
    _userId = user['user_id'];
    _email = user['email'];
    _displayName = user['display_name'];
    _role = user['role'];

    await _prefs?.setString(_userIdKey, _userId ?? '');
    await _prefs?.setString(_emailKey, _email ?? '');
    await _prefs?.setString(_displayNameKey, _displayName ?? '');
    if (_role != null) {
      await _prefs?.setString(_roleKey, _role!);
    }
  }

  /// Sign out - clear local data
  Future<void> signOut() async {
    _userId = null;
    _email = null;
    _displayName = null;
    _role = null;

    await _prefs?.remove(_userIdKey);
    await _prefs?.remove(_emailKey);
    await _prefs?.remove(_displayNameKey);
    await _prefs?.remove(_roleKey);
  }

  /// Dispose the HTTP client
  void dispose() {
    _client.close();
  }
}
