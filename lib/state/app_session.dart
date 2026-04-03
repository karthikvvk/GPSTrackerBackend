import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/services/auth_service.dart';
import 'package:gpstracking/services/background_service.dart';
import 'package:gpstracking/services/location_service.dart';
import 'package:gpstracking/services/relay_service.dart';
import 'package:gpstracking/utils/location_helper.dart';
import 'package:gpstracking/utils/battery_helper.dart';

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
  bool get isChild => _role == UserRole.child;
  bool get isParent => _role == UserRole.parent;
  bool get hasRole => _role != null;

  // =========================================================================
  // Tracking State (Child mode)
  // =========================================================================

  bool _trackingActive = false;
  CoordinateLog? _lastLocation;
  bool _childOnline = false;
  LocationService? _locationService;
  RelayService? _relayService;
  StreamSubscription? _liveLocationSub;
  StreamSubscription? _childStatusSub;
  StreamSubscription? _syncBatchSub;
  final List<String> _trackingLogs = [];

  final _syncCompletedController = StreamController<void>.broadcast();
  Stream<void> get syncCompleted => _syncCompletedController.stream;

  bool get trackingActive => _trackingActive;
  CoordinateLog? get lastLocation => _lastLocation;
  bool get childOnline => _childOnline;
  RelayService? get relayService => _relayService;
  List<String> get trackingLogs => List.unmodifiable(_trackingLogs);

  // =========================================================================
  // Linked Children (Parent mode)
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

      final roleStr = _authService.role;
      if (roleStr != null) {
        _role = roleStr == 'child' ? UserRole.child : UserRole.parent;
      }

      // FIX 3: Restore linked child from persisted storage so pages
      // that call triggerSync() on load don't crash with null _selectedChildId.
      final linkedChildId = _authService.linkedChildId;
      final linkedChildName = _authService.linkedChildName;
      if (linkedChildId != null && linkedChildName != null) {
        _selectedChildId = linkedChildId;
        _linkedChildName = linkedChildName;
        _linkedChildren = [
          LinkedChild(
            odemoId: linkedChildId,
            displayName: linkedChildName,
            email: linkedChildName,
          )
        ];
        if (kDebugMode) {
          print(
              '[AppSession] Restored linked child: $linkedChildId ($linkedChildName)');
        }
      }

      if (_role == UserRole.child) {
        _trackingActive = await BackgroundService.isRunning();
        if (_trackingActive) {
          _trackingLogs.add('Restored tracking state on app reopen');
        }
      }

      notifyListeners();
    }
  }

  // =========================================================================
  // Authentication Methods
  // =========================================================================

  Future<bool> signInWithEmail(String email, String password) async {
    try {
      final user = await _authService.login(email: email, password: password);
      if (user != null) {
        _signedIn = true;
        _userId = user['user_id'];
        _displayName = user['display_name'];
        _email = user['email'];
        _viewerName = _displayName ?? 'You';

        final roleStr = user['role'];
        if (roleStr != null) {
          _role = roleStr == 'child' ? UserRole.child : UserRole.parent;
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

  Future<Map<String, dynamic>?> createAccount(
      String email, String password, String displayName) async {
    try {
      return await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
      );
    } catch (e) {
      if (kDebugMode) print('[AppSession] Create account error: $e');
      rethrow;
    }
  }

  void completeSignIn(Map<String, dynamic> user) {
    _signedIn = true;
    _userId = user['user_id'];
    _displayName = user['display_name'];
    _email = user['email'];
    _viewerName = _displayName ?? 'You';

    final roleStr = user['role'];
    if (roleStr != null) {
      _role = roleStr == 'child' ? UserRole.child : UserRole.parent;
    }

    notifyListeners();
  }

  Future<bool> signUpWithEmail(
      String email, String password, String displayName) async {
    try {
      final user = await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
      );
      if (user != null) {
        completeSignIn(user);
        return true;
      }
      return false;
    } catch (e) {
      if (kDebugMode) print('[AppSession] Sign up error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    _locationService?.stopTracking();
    _liveLocationSub?.cancel();
    _childStatusSub?.cancel();
    _syncBatchSub?.cancel();
    _relayService?.disconnect();
    _relayService = null;

    await _authService.signOut(); // also clears linkedChildId/Name
    _signedIn = false;
    _userId = null;
    _displayName = null;
    _email = null;
    _role = null;
    _trackingActive = false;
    _lastLocation = null;
    _linkedChildren = [];
    _selectedChildId = null;
    _linkedChildName = null;
    _viewerName = 'You';
    notifyListeners();
  }

  void signIn() {
    _signedIn = true;
    notifyListeners();
  }

  // =========================================================================
  // Role Methods
  // =========================================================================

  void setRole(UserRole role) {
    _role = role;
    _authService.updateRole(role == UserRole.child ? 'child' : 'parent');
    notifyListeners();
  }

  void clearRole() {
    _role = null;
    notifyListeners();
  }

  // =========================================================================
  // Tracking Methods (Child)
  // =========================================================================

  void setTrackingActive(bool active) {
    _trackingActive = active;
    notifyListeners();
  }

  void updateLocation(CoordinateLog location) {
    _lastLocation = location;
    notifyListeners();
  }

  void setChildOnline(bool online) {
    _childOnline = online;
    notifyListeners();
  }

  // =========================================================================
  // Child Relay Methods
  // =========================================================================

  Future<void> connectChildRelay() async {
    if (_userId == null || !isChild) return;
    if (_relayService != null && _relayService!.isConnected) return;

    _relayService?.disconnect();
    _relayService = RelayService();
    await _relayService!.connect(userId: _userId!, isChild: true);
    if (kDebugMode) print('[AppSession] Child relay connected (presence only)');
  }

  Future<void> startTracking([BuildContext? context]) async {
    if (_trackingActive || _userId == null) return;

    if (context != null) {
      final ok = await ensureLocationEnabled(context);
      if (!ok) return;
    }

    if (_relayService == null || !_relayService!.isConnected) {
      _liveLocationSub?.cancel();
      _childStatusSub?.cancel();
      _relayService?.disconnect();
      _relayService = RelayService();
      await _relayService!.connect(userId: _userId!, isChild: true);
    }

    _locationService ??= LocationService(userId: _userId!);
    _locationService!.attachRelay(_relayService!);
    _locationService!
      ..onStatusUpdate = (msg) {
        _trackingLogs.add(msg);
        if (_trackingLogs.length > 50) _trackingLogs.removeAt(0);
        notifyListeners();
      }
      ..onLocationUpdate = (log) {
        _lastLocation = log;
        notifyListeners();
      };

    await _locationService!.startTracking();
    await requestBatteryOptimizationExemption(context);
    await BackgroundService.startService(_userId!);

    _trackingActive = true;
    _trackingLogs.add('Started tracking');
    notifyListeners();
  }

  // =========================================================================
  // Parent Relay Methods
  // =========================================================================

  /// Connect relay as parent, subscribe to live stream, and set up sync listener.
  ///
  /// FIX 1: Now passes childId directly to connect() so RelayService has it
  /// from the start — no more null childId assert crash.
  ///
  /// FIX 2: Removed the incorrect subscribeToChild() call before connect().
  /// The new connect() handles subscription internally via _onConnected().
  Future<void> connectAsParent(String childId) async {
    if (_userId == null) return;

    // Guard: never connect as parent to your own userId
    if (childId == _userId) {
      if (kDebugMode) {
        print('[AppSession] ❌ connectAsParent blocked: childId == own userId');
        print(
            '[AppSession]    This means _selectedChildId was never set correctly.');
        print('[AppSession]    Call linkChild() before connectAsParent().');
      }
      return;
    }

    // Idempotency guard
    if (_selectedChildId == childId && (_relayService?.isConnected ?? false)) {
      return;
    }

    // Tear down cleanly
    _liveLocationSub?.cancel();
    _childStatusSub?.cancel();
    _syncBatchSub?.cancel();
    _relayService?.disconnect();
    _relayService = RelayService();

    // FIX 1+2: Pass childId directly to connect() — no subscribeToChild() before connect()
    await _relayService!.connect(
      userId: _userId!,
      isChild: false,
      childId: childId, // ← this was missing before, causing the assert crash
    );

    if (kDebugMode) {
      print('[AppSession] connectAsParent: connected as parent');
      print('[AppSession]   parentId = $_userId');
      print('[AppSession]   childId  = $childId');
    }

    // Listen for live locations
    _liveLocationSub = _relayService!.liveLocationStream.listen((coord) {
      _lastLocation = coord;
      notifyListeners();
      LocalDb.insertLog(coord).catchError((e) {
        if (kDebugMode) print('[AppSession] Failed to save relayed coord: $e');
      });
    });

    // Listen for child online/offline status
    _childStatusSub = _relayService!.childStatusStream.listen((online) {
      _childOnline = online;
      notifyListeners();
    });

    // Collect sync batches and flush to DB
    _syncBatchSub = _relayService!.syncBatchStream.listen((batch) async {
      final rawCoords = batch.coords;
      final done = batch.done;

      final coords = <CoordinateLog>[];
      for (final raw in rawCoords) {
        try {
          coords.add(CoordinateLog(
            xCord: (raw['x_cord'] as num).toDouble(),
            yCord: (raw['y_cord'] as num).toDouble(),
            loggedTime: raw['logged_time'] as String,
            userId: childId,
            synced: true,
          ));
        } catch (e) {
          if (kDebugMode) print('[AppSession] Sync parse error: $e');
        }
      }
      if (coords.isNotEmpty) {
        await LocalDb.insertLogsBatch(coords).catchError((e) {
          if (kDebugMode) print('[AppSession] Sync batch insert error: $e');
        });
        if (kDebugMode)
          print('[AppSession] Batch inserted ${coords.length} records');
      }
      if (done) {
        _syncCompletedController.add(null);
        if (kDebugMode)
          print('[AppSession] Sync complete — notified listeners');
      }
    });
  }

  Future<void> stopTracking() async {
    _locationService?.stopTracking();
    await BackgroundService.stopService();
    _locationService?.attachRelay(null);
    _trackingActive = false;
    _trackingLogs.add('Stopped tracking');
    notifyListeners();
  }

  // =========================================================================
  // Linked Children Methods (Parent)
  // =========================================================================

  void addLinkedChild(LinkedChild child) {
    _linkedChildren.add(child);
    if (_selectedChildId == null) {
      _selectedChildId = child.odemoId;
    }
    notifyListeners();
  }

  void removeLinkedChild(String odemoId) {
    _linkedChildren.removeWhere((c) => c.odemoId == odemoId);
    if (_selectedChildId == odemoId) {
      _selectedChildId =
          _linkedChildren.isNotEmpty ? _linkedChildren.first.odemoId : null;
    }
    notifyListeners();
  }

  void selectChild(String? odemoId) {
    _selectedChildId = odemoId;
    notifyListeners();
  }

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

  /// Link a child account by name and userId, then persist it so it
  /// survives app restarts.
  ///
  /// FIX 3: Now persists linkedChildId and linkedChildName to SharedPreferences
  /// via AuthService so _selectedChildId is never null after a restart.
  void linkChild({required String childName, required String childUserId}) {
    // Guard: never link own account as child
    if (childUserId == _userId) {
      if (kDebugMode) {
        print(
            '[AppSession] ❌ linkChild blocked: childUserId == own userId ($childUserId)');
        print(
            '[AppSession]    The parent tried to link themselves as the child.');
        print('[AppSession]    Check the QR/email lookup result.');
      }
      return;
    }

    final trimmed = childName.trim();
    _linkedChildName = trimmed.isEmpty ? null : trimmed;

    final alreadyLinked = _linkedChildren.any((c) => c.odemoId == childUserId);
    if (!alreadyLinked && trimmed.isNotEmpty) {
      _linkedChildren.add(LinkedChild(
        odemoId: childUserId,
        displayName: trimmed,
        email: trimmed,
      ));
    }
    _selectedChildId = childUserId;

    // FIX 3: Persist so it survives app restarts
    _authService.saveLinkedChild(childUserId: childUserId, childName: trimmed);

    notifyListeners();

    // Connect relay and kick off full sync
    connectAsParent(childUserId);
  }

  Future<String?> lookupChildByEmail(String email) async {
    try {
      final user = await _authService.lookupByEmail(email.trim().toLowerCase());
      if (user == null) return 'No user found with that email.';
      final childUserId = user['user_id'] as String;
      final childName = (user['display_name'] as String?)?.isNotEmpty == true
          ? user['display_name'] as String
          : user['email'] as String? ?? email;
      linkChild(childName: childName, childUserId: childUserId);
      return null;
    } catch (e) {
      if (kDebugMode) print('[AppSession] lookupChildByEmail error: $e');
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Request an incremental DB sync for the currently selected child.
  /// Safe to call from any page — guards against null selectedChildId.
  Future<void> triggerSync() async {
    final childId = _selectedChildId;

    // FIX 3: Guard against null _selectedChildId (happens after restart
    // if linked child was not persisted)
    if (childId == null) {
      if (kDebugMode)
        print('[AppSession] triggerSync: no child selected — skipped');
      return;
    }

    if (childId == _userId) {
      if (kDebugMode)
        print('[AppSession] triggerSync: childId == own userId — skipped');
      return;
    }

    if (_relayService == null || !_relayService!.isConnected) {
      if (kDebugMode)
        print('[AppSession] triggerSync: relay not ready — connecting first');
      await connectAsParent(childId);
    }

    _relayService?.requestSync(childId);
    if (kDebugMode)
      print('[AppSession] triggerSync: sync requested for $childId');
  }

  void unlinkChild() {
    _linkedChildName = null;
    _linkedChildren.clear();
    _selectedChildId = null;
    _authService.clearLinkedChild();
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
