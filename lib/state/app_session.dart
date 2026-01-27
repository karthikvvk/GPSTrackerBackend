import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/services/auth_service.dart';

/// App session state - manages authentication, role, and tracking state
class AppSession extends ChangeNotifier {
  final AuthService _authService;

  // =========================================================================
  // Auth State
  // =========================================================================

  bool _signedIn = false;
  String? _userId;
  String? _displayName;
  String? _email;

  bool get signedIn => _signedIn;
  String? get userId => _userId;
  String? get displayName => _displayName ?? 'User';
  String? get email => _email;

  // =========================================================================
  // Role State
  // =========================================================================

  UserRole? _role;

  UserRole? get role => _role;
  bool get isKodomo => _role == UserRole.kodomo;
  bool get isKazoku => _role == UserRole.kazoku;
  bool get hasRole => _role != null;

  // =========================================================================
  // Tracking State (Kodomo mode)
  // =========================================================================

  bool _trackingActive = false;
  CoordinateLog? _lastLocation;
  bool _serverUp = false;
  int _backupCount = 0;

  bool get trackingActive => _trackingActive;
  CoordinateLog? get lastLocation => _lastLocation;
  bool get serverUp => _serverUp;
  int get backupCount => _backupCount;

  // =========================================================================
  // Linked Children (Kazoku mode)
  // =========================================================================

  List<LinkedChild> _linkedChildren = [];
  String? _selectedChildId;

  List<LinkedChild> get linkedChildren => List.unmodifiable(_linkedChildren);
  String? get selectedChildId => _selectedChildId;

  LinkedChild? get selectedChild {
    if (_selectedChildId == null) return null;
    try {
      return _linkedChildren.firstWhere((c) => c.odemoId == _selectedChildId);
    } catch (_) {
      return null;
    }
  }

  /// Display name of the currently signed-in account
  String _viewerName = 'You';
  String? _linkedChildName;

  String get viewerName => _viewerName;
  String? get linkedChildName => _linkedChildName;
  bool get hasLinkedChild =>
      _linkedChildName != null && _linkedChildName!.trim().isNotEmpty;
  String get subjectName => hasLinkedChild ? _linkedChildName!.trim() : 'You';

  // =========================================================================
  // Constructor
  // =========================================================================

  AppSession({AuthService? authService})
      : _authService = authService ?? AuthService() {
    _initializeAuth();
  }

  Future<void> _initializeAuth() async {
    await _authService.initialize();
    if (_authService.isSignedIn) {
      _signedIn = true;
      _userId = _authService.userId;
      _displayName = _authService.displayName;
      _email = _authService.email;
      _viewerName = _displayName ?? 'You';

      // Restore role if saved
      final roleStr = _authService.role;
      if (roleStr != null) {
        _role = roleStr == 'kodomo' ? UserRole.kodomo : UserRole.kazoku;
      }

      notifyListeners();
    }
  }

  // =========================================================================
  // Authentication Methods
  // =========================================================================

  /// Sign in with email and password
  Future<bool> signInWithEmail(String email, String password) async {
    try {
      final user = await _authService.login(email: email, password: password);
      if (user != null) {
        _signedIn = true;
        _userId = user['user_id'];
        _displayName = user['display_name'];
        _email = user['email'];
        _viewerName = _displayName ?? 'You';

        // Restore role if saved
        final roleStr = user['role'];
        if (roleStr != null) {
          _role = roleStr == 'kodomo' ? UserRole.kodomo : UserRole.kazoku;
        }

        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('[AppSession] Sign in error: $e');
      rethrow;
    }
  }

  /// Sign up with email and password
  Future<bool> signUpWithEmail(
      String email, String password, String displayName) async {
    try {
      final user = await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (user != null) {
        _signedIn = true;
        _userId = user['user_id'];
        _displayName = user['display_name'];
        _email = user['email'];
        _viewerName = _displayName ?? 'You';
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('[AppSession] Sign up error: $e');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    _signedIn = false;
    _userId = null;
    _displayName = null;
    _email = null;
    _role = null;
    _trackingActive = false;
    _lastLocation = null;
    _linkedChildren = [];
    _selectedChildId = null;
    _viewerName = 'You';
    _linkedChildName = null;
    notifyListeners();
  }

  /// Simulate sign in (for testing)
  void signIn() {
    _signedIn = true;
    notifyListeners();
  }

  // =========================================================================
  // Role Methods
  // =========================================================================

  /// Set user role
  void setRole(UserRole role) {
    _role = role;
    // Save role to backend
    _authService.updateRole(role == UserRole.kodomo ? 'kodomo' : 'kazoku');
    notifyListeners();
  }

  /// Clear role (go back to role selection)
  void clearRole() {
    _role = null;
    notifyListeners();
  }

  // =========================================================================
  // Tracking Methods (Kodomo)
  // =========================================================================

  /// Update tracking status
  void setTrackingActive(bool active) {
    _trackingActive = active;
    notifyListeners();
  }

  /// Update last location
  void updateLocation(CoordinateLog location) {
    _lastLocation = location;
    notifyListeners();
  }

  /// Update server status
  void setServerUp(bool up) {
    _serverUp = up;
    notifyListeners();
  }

  /// Update backup count
  void setBackupCount(int count) {
    _backupCount = count;
    notifyListeners();
  }

  // =========================================================================
  // Linked Children Methods (Kazoku)
  // =========================================================================

  /// Add a linked child
  void addLinkedChild(LinkedChild child) {
    _linkedChildren.add(child);
    if (_selectedChildId == null) {
      _selectedChildId = child.odemoId;
    }
    notifyListeners();
  }

  /// Remove a linked child
  void removeLinkedChild(String odemoId) {
    _linkedChildren.removeWhere((c) => c.odemoId == odemoId);
    if (_selectedChildId == odemoId) {
      _selectedChildId =
          _linkedChildren.isNotEmpty ? _linkedChildren.first.odemoId : null;
    }
    notifyListeners();
  }

  /// Select which child to view
  void selectChild(String? odemoId) {
    _selectedChildId = odemoId;
    notifyListeners();
  }

  /// Update a child's last location
  void updateChildLocation(String odemoId, CoordinateLog location) {
    final index = _linkedChildren.indexWhere((c) => c.odemoId == odemoId);
    if (index != -1) {
      _linkedChildren[index] = _linkedChildren[index].copyWith(
        lastLocation: location,
        lastSeen: DateTime.now(),
      );
      notifyListeners();
    }
  }

  /// UI-only helper: simulates linking to a child account (from original)
  void linkChild({required String childName}) {
    final trimmed = childName.trim();
    _linkedChildName = trimmed.isEmpty ? null : trimmed;
    notifyListeners();
  }

  /// UI-only helper: removes the linked child account (from original)
  void unlinkChild() {
    _linkedChildName = null;
    notifyListeners();
  }
  // =========================================================================
  // Theme State
  // =========================================================================

  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
