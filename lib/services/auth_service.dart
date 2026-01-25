import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Authentication service using Firebase Auth
class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  SharedPreferences? _prefs;

  static const String _roleKey = 'user_role';

  // Cached user data
  User? _user;
  String? _role;

  AuthService();

  /// Initialize and load cached user data
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _role = _prefs?.getString(_roleKey);
    
    // Listen to verification state changes
    _firebaseAuth.authStateChanges().listen((User? user) {
      _user = user;
    });
    
    // Wait for initial auth state (optional, usually handled by stream)
    _user = _firebaseAuth.currentUser;
  }

  /// Get current user ID
  String? get userId => _user?.uid;

  /// Get display name
  String? get displayName => _user?.displayName;

  /// Get email
  String? get email => _user?.email;

  /// Get role
  String? get role => _role;

  /// Check if user is signed in
  bool get isSignedIn => _user != null;

  /// Register a new user
  Future<Map<String, dynamic>?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      await credential.user?.updateDisplayName(displayName);
      await credential.user?.reload();
      _user = _firebaseAuth.currentUser;

      return _userToMap(_user!);
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
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _user = credential.user;
      return _userToMap(_user!);
    } catch (e) {
      rethrow;
    }
  }

  /// Update user role
  Future<void> updateRole(String role) async {
    _role = role;
    await _prefs?.setString(_roleKey, role);
  }

  /// Sign out
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    _user = null;
    _role = null;
    await _prefs?.remove(_roleKey);
  }

  /// Helper to convert Firebase User to Map for simple compatibility
  Map<String, dynamic> _userToMap(User user) {
    return {
      'user_id': user.uid,
      'email': user.email,
      'display_name': user.displayName,
      'role': _role, // Role persists independently for now
    };
  }
}
