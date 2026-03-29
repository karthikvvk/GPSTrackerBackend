import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gpstracking/utils/settings.dart';

/// Authentication service — manual HTTP-based auth against the Flask backend.
/// No Firebase. Sessions are persisted in SharedPreferences.
class AuthService {
  SharedPreferences? _prefs;

  // SharedPreferences keys
  static const String _keyUserId = 'user_id';
  static const String _keyEmail = 'user_email';
  static const String _keyDisplayName = 'user_display_name';
  static const String _keyRole = 'user_role';

  // In-memory cache
  String? _userId;
  String? _email;
  String? _displayName;
  String? _role;

  AuthService();

  // ---------------------------------------------------------------------------
  // Initialisation — restores persisted session on app start
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _userId = _prefs?.getString(_keyUserId);
    _email = _prefs?.getString(_keyEmail);
    _displayName = _prefs?.getString(_keyDisplayName);
    _role = _prefs?.getString(_keyRole);
  }

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get role => _role;
  bool get isSignedIn => _userId != null;

  // ---------------------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------------------

  /// Register a new user. Returns the resolved user map on success.
  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final settings = await Settings.instance;
    final url = Uri.parse('${settings.backendUrl}/auth/register');
    print('printing url');
    print(url);
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
    );
    print(response);
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    print(body);
    if (response.statusCode == 201 && body['status'] == 'success') {
      final user = body['user'] as Map<String, dynamic>;
      await _persistSession(user);
      return user;
    }

    throw Exception(body['message'] ?? 'Registration failed');
  }

  // ---------------------------------------------------------------------------
  // Login
  // ---------------------------------------------------------------------------

  /// Login with email and password. Returns the user map on success.
  Future<Map<String, dynamic>?> login({
    required String email,
    required String password,
  }) async {
    final settings = await Settings.instance;
    final url = Uri.parse('${settings.backendUrl}/auth/login');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && body['status'] == 'success') {
      final user = body['user'] as Map<String, dynamic>;
      await _persistSession(user);
      return user;
    }

    throw Exception(body['message'] ?? 'Login failed');
  }

  // ---------------------------------------------------------------------------
  // Lookup by email (for parent linking a child account)
  // ---------------------------------------------------------------------------

  /// Look up a user's public info (user_id, display_name) by email.
  /// Used by the parent's "Link Account" email method.
  Future<Map<String, dynamic>?> lookupByEmail(String email) async {
    final settings = await Settings.instance;
    final url = Uri.parse(
      '${settings.backendUrl}/auth/lookup?email=${Uri.encodeComponent(email)}',
    );

    final response = await http.get(url);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 && body['status'] == 'success') {
      return body['user'] as Map<String, dynamic>;
    }

    throw Exception(body['message'] ?? 'User not found');
  }

  // ---------------------------------------------------------------------------
  // Update role
  // ---------------------------------------------------------------------------

  /// Persist role locally and sync to the backend profile.
  Future<void> updateRole(String role) async {
    _role = role;
    await _prefs?.setString(_keyRole, role);

    // Best-effort sync to backend — non-critical
    if (_userId != null) {
      try {
        final settings = await Settings.instance;
        await http.put(
          Uri.parse('${settings.backendUrl}/auth/profile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': _userId, 'role': role}),
        );
      } catch (_) {
        // Ignore failures — role is already saved locally
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    _userId = null;
    _email = null;
    _displayName = null;
    _role = null;
    await _prefs?.remove(_keyUserId);
    await _prefs?.remove(_keyEmail);
    await _prefs?.remove(_keyDisplayName);
    await _prefs?.remove(_keyRole);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _persistSession(Map<String, dynamic> user) async {
    _userId = user['user_id'] as String?;
    _email = user['email'] as String?;
    _displayName = user['display_name'] as String?;
    _role = user['role'] as String?;

    await _prefs?.setString(_keyUserId, _userId ?? '');
    await _prefs?.setString(_keyEmail, _email ?? '');
    await _prefs?.setString(_keyDisplayName, _displayName ?? '');
    if (_role != null) {
      await _prefs?.setString(_keyRole, _role!);
    }
  }
}
