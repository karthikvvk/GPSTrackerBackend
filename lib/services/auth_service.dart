import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:gpstracking/utils/settings.dart';

/// Authentication service — manual HTTP-based auth against the Flask backend.
class AuthService {
  SharedPreferences? _prefs;

  static const String _keyUserId = 'user_id';
  static const String _keyEmail = 'user_email';
  static const String _keyDisplayName = 'user_display_name';
  static const String _keyRole = 'user_role';

  // FIX 3: Keys for persisting the linked child across restarts
  static const String _keyLinkedChildId = 'linked_child_id';
  static const String _keyLinkedChildName = 'linked_child_name';

  String? _userId;
  String? _email;
  String? _displayName;
  String? _role;
  String? _linkedChildId;
  String? _linkedChildName;

  AuthService();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _userId = _prefs?.getString(_keyUserId);
    _email = _prefs?.getString(_keyEmail);
    _displayName = _prefs?.getString(_keyDisplayName);
    _role = _prefs?.getString(_keyRole);
    _linkedChildId = _prefs?.getString(_keyLinkedChildId);
    _linkedChildName = _prefs?.getString(_keyLinkedChildName);
  }

  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get role => _role;
  bool get isSignedIn => _userId != null;

  // FIX 3: Expose persisted linked child to AppSession on restore
  String? get linkedChildId => _linkedChildId;
  String? get linkedChildName => _linkedChildName;

  // ---------------------------------------------------------------------------
  // Register
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final settings = await Settings.instance;
    final url = Uri.parse('${settings.backendUrl}/auth/register');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'display_name': displayName,
      }),
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;
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
  // Lookup by email
  // ---------------------------------------------------------------------------

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

  Future<void> updateRole(String role) async {
    _role = role;
    await _prefs?.setString(_keyRole, role);
    if (_userId != null) {
      try {
        final settings = await Settings.instance;
        await http.put(
          Uri.parse('${settings.backendUrl}/auth/profile'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'user_id': _userId, 'role': role}),
        );
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // FIX 3: Save / clear linked child
  // ---------------------------------------------------------------------------

  /// Persist the linked child's ID and display name so it survives app restarts.
  Future<void> saveLinkedChild({
    required String childUserId,
    required String childName,
  }) async {
    _linkedChildId = childUserId;
    _linkedChildName = childName;
    await _prefs?.setString(_keyLinkedChildId, childUserId);
    await _prefs?.setString(_keyLinkedChildName, childName);
  }

  /// Clear the persisted linked child (called on unlink or sign out).
  Future<void> clearLinkedChild() async {
    _linkedChildId = null;
    _linkedChildName = null;
    await _prefs?.remove(_keyLinkedChildId);
    await _prefs?.remove(_keyLinkedChildName);
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  Future<void> signOut() async {
    _userId = null;
    _email = null;
    _displayName = null;
    _role = null;
    _linkedChildId = null;
    _linkedChildName = null;
    await _prefs?.remove(_keyUserId);
    await _prefs?.remove(_keyEmail);
    await _prefs?.remove(_keyDisplayName);
    await _prefs?.remove(_keyRole);
    await _prefs?.remove(_keyLinkedChildId);
    await _prefs?.remove(_keyLinkedChildName);
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
