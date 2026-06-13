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

  // Legacy single-child keys (read-only for one-time migration)
  static const String _keyLinkedChildId = 'linked_child_id';
  static const String _keyLinkedChildName = 'linked_child_name';

  // Multi-child list key — source of truth: JSON array [{"id":"...","name":"..."},...]
  static const String _keyLinkedChildrenList = 'linked_children_list';

  String? _userId;
  String? _email;
  String? _displayName;
  String? _role;

  // In-memory multi-child list [{"id":"...","name":"..."},...].
  List<Map<String, String>> _linkedChildrenList = [];

  AuthService();

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _userId = _prefs?.getString(_keyUserId);
    _email = _prefs?.getString(_keyEmail);
    _displayName = _prefs?.getString(_keyDisplayName);
    _role = _prefs?.getString(_keyRole);

    // Load multi-child list from SharedPrefs.
    final raw = _prefs?.getString(_keyLinkedChildrenList);
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw) as List<dynamic>;
      _linkedChildrenList = decoded
          .cast<Map<String, dynamic>>()
          .map((m) => {'id': m['id'] as String, 'name': m['name'] as String})
          .toList();
    } else {
      // One-time migration from legacy single-child keys.
      final legacyId = _prefs?.getString(_keyLinkedChildId);
      final legacyName = _prefs?.getString(_keyLinkedChildName);
      if (legacyId != null && legacyName != null) {
        _linkedChildrenList = [{'id': legacyId, 'name': legacyName}];
        await _persistChildrenList();
      }
    }
  }

  String? get userId => _userId;
  String? get email => _email;
  String? get displayName => _displayName;
  String? get role => _role;
  bool get isSignedIn => _userId != null;

  /// All persisted linked children as [{"id":"...","name":"..."},...] maps.
  List<Map<String, String>> get linkedChildren =>
      List.unmodifiable(_linkedChildrenList);

  // Legacy getters kept for any callers that still use single-child API.
  String? get linkedChildId =>
      _linkedChildrenList.isNotEmpty ? _linkedChildrenList.first['id'] : null;
  String? get linkedChildName =>
      _linkedChildrenList.isNotEmpty ? _linkedChildrenList.first['name'] : null;

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
  // Save / clear linked children (multi-child list)
  // ---------------------------------------------------------------------------

  /// Upsert a child into the persisted list. Safe to call multiple times.
  Future<void> saveLinkedChild({
    required String childUserId,
    required String childName,
  }) async {
    // Upsert: remove existing entry with same id, then append.
    _linkedChildrenList.removeWhere((m) => m['id'] == childUserId);
    _linkedChildrenList.add({'id': childUserId, 'name': childName});
    await _persistChildrenList();
  }

  /// Remove a single child from the persisted list.
  Future<void> clearLinkedChild(String childUserId) async {
    _linkedChildrenList.removeWhere((m) => m['id'] == childUserId);
    await _persistChildrenList();
  }

  /// Remove all linked children (called on sign-out).
  Future<void> clearAllLinkedChildren() async {
    _linkedChildrenList.clear();
    await _prefs?.remove(_keyLinkedChildrenList);
    // Also clear legacy keys.
    await _prefs?.remove(_keyLinkedChildId);
    await _prefs?.remove(_keyLinkedChildName);
  }

  Future<void> _persistChildrenList() async {
    final encoded = jsonEncode(_linkedChildrenList);
    await _prefs?.setString(_keyLinkedChildrenList, encoded);
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
    await clearAllLinkedChildren();
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
