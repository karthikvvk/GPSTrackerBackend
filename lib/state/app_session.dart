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

  // Fires when an entire sync run completes (done=true received).
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
        _role = roleStr == 'child' ? UserRole.child : UserRole.parent;
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

  /// Create account without automatic sign-in state update (for custom flows)
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

  /// Manually complete sign-in after custom flow
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
        completeSignIn(user);
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
    // Stop tracking and disconnect relay before clearing state
    _locationService?.stopTracking();
    _liveLocationSub?.cancel();
    _childStatusSub?.cancel();
    _relayService?.disconnect();
    _relayService = null;

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
    _authService.updateRole(role == UserRole.child ? 'child' : 'parent');
    notifyListeners();
  }

  /// Clear role (go back to role selection)
  void clearRole() {
    _role = null;
    notifyListeners();
  }

  // =========================================================================
  // Tracking Methods (Child)
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

  /// Update child online status (parent mode)
  void setChildOnline(bool online) {
    _childOnline = online;
    notifyListeners();
  }

  // =========================================================================
  // Child Relay Methods
  // =========================================================================

  /// Connect the child to the relay server and register as online.
  ///
  /// Call this when the child dashboard loads so the child appears "online"
  /// to parents even before tracking is started (e.g. user is at home,
  /// app is open but GPS sharing is off).
  Future<void> connectChildRelay() async {
    if (_userId == null || !isChild) return;
    // Already connected as child — nothing to do.
    if (_relayService != null && _relayService!.isConnected) return;

    _relayService?.disconnect();
    _relayService = RelayService();
    await _relayService!.connect(userId: _userId!, isChild: true);
    if (kDebugMode) print('[AppSession] Child relay connected (presence only)');
  }

  /// Start GPS location tracking (child mode).
  ///
  /// Reuses the relay connection if already established by [connectChildRelay].
  /// Pass a [BuildContext] to prompt the user for location permissions.
  Future<void> startTracking([BuildContext? context]) async {
    if (_trackingActive || _userId == null) return;

    // Ensure location services & permissions before starting
    if (context != null) {
      final ok = await ensureLocationEnabled(context);
      if (!ok) return;
    }

    // Reuse the existing child-mode relay if it's already connected.
    // Only tear down + recreate if the relay is missing or in parent mode.
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
    await BackgroundService.startService(_userId!);

    _trackingActive = true;
    _trackingLogs.add('Started tracking');
    notifyListeners();
  }

  /// Connect relay as parent, subscribe to live stream, and trigger DB sync.
  Future<void> connectAsParent(String childId) async {
    if (_userId == null) return;

    // Idempotency guard — don't reconnect if already watching this child.
    if (_selectedChildId == childId && (_relayService?.isConnected ?? false)) {
      return;
    }

    // Tear down any existing relay cleanly.
    _liveLocationSub?.cancel();
    _childStatusSub?.cancel();
    _syncBatchSub?.cancel();
    _relayService?.disconnect();
    _relayService = RelayService();

    // Set _pendingChildId before connecting so the subscription fires
    // inside onConnect — not before the socket is open.
    _relayService!.subscribeToChild(childId);

    await _relayService!.connect(userId: _userId!, isChild: false);

    // Listen for live locations and persist to local SQLite (history calendar).
    _liveLocationSub = _relayService!.liveLocationStream.listen((coord) {
      _lastLocation = coord;
      notifyListeners();
      LocalDb.insertLog(coord).catchError((e) {
        if (kDebugMode) print('[AppSession] Failed to save relayed coord: $e');
      });
    });

    // Listen for child online/offline status.
    _childStatusSub = _relayService!.childStatusStream.listen((online) {
      _childOnline = online;
      notifyListeners();
    });

    // Collect sync batch records and flush them all in one DB transaction.
    // This avoids the DB lock contention from individual insertLog calls
    // competing with the background service's continuous location writes.
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
        if (kDebugMode) print('[AppSession] Batch inserted ${coords.length} records');
      }
      if (done) {
        _syncCompletedController.add(null);
        if (kDebugMode) print('[AppSession] Sync complete — notified listeners');
      }
    });
    // NOTE: auto-sync is NOT triggered here intentionally.
    // Sync is triggered explicitly by History/TripDetails page visits via triggerSync().
  }


  /// Stop GPS tracking but keep the relay alive (child stays "online").
  Future<void> stopTracking() async {
    _locationService?.stopTracking();
    await BackgroundService.stopService();

    // Detach relay from location service so no more pushLocation calls,
    // but keep the WebSocket open so the child stays visible as "online".
    _locationService?.attachRelay(null);

    _trackingActive = false;
    _trackingLogs.add('Stopped tracking');
    notifyListeners();
  }

  // =========================================================================
  // Linked Children Methods (Parent)
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

  /// Link a child account by name and userId.
  void linkChild({required String childName, required String childUserId}) {
    final trimmed = childName.trim();
    _linkedChildName = trimmed.isEmpty ? null : trimmed;

    // Register as a full LinkedChild so data-fetching works.
    final alreadyLinked = _linkedChildren.any((c) => c.odemoId == childUserId);
    if (!alreadyLinked && trimmed.isNotEmpty) {
      _linkedChildren.add(LinkedChild(
        odemoId: childUserId,
        displayName: trimmed,
        email: trimmed,
      ));
    }
    _selectedChildId = childUserId;
    notifyListeners();

    // After linking, establish the relay connection and kick off a full sync
    // so the History calendar starts populating immediately.
    connectAsParent(childUserId);
  }

  /// Look up a child account by email via the backend, then link it.
  /// Used by the parent's Email Method on the Link Account page.
  /// Returns an error message string on failure, or null on success.
  Future<String?> lookupChildByEmail(String email) async {
    try {
      final user = await _authService.lookupByEmail(email.trim().toLowerCase());
      if (user == null) return 'No user found with that email.';
      final childUserId = user['user_id'] as String;
      final childName   = (user['display_name'] as String?)?.isNotEmpty == true
          ? user['display_name'] as String
          : user['email'] as String? ?? email;
      linkChild(childName: childName, childUserId: childUserId);
      return null; // success
    } catch (e) {
      if (kDebugMode) print('[AppSession] lookupChildByEmail error: $e');
      return e.toString().replaceAll('Exception: ', '');
    }
  }

  /// Request an incremental DB sync for the currently selected child.
  ///
  /// Safe to call from any page (History calendar, Live Map, etc.).
  /// Automatically connects the relay if it isn't already up.
  Future<void> triggerSync() async {
    final childId = _selectedChildId;
    if (childId == null) {
      if (kDebugMode) print('[AppSession] triggerSync: no child selected — skipped');
      return;
    }

    // Ensure relay exists and is connected as parent.
    // connectAsParent is idempotent — safe to call even if already connected.
    if (_relayService == null || !_relayService!.isConnected) {
      if (kDebugMode) print('[AppSession] triggerSync: relay not ready — connecting first');
      await connectAsParent(childId);
      // requestSync uses _pendingSyncChildId to queue if socket isn't open yet.
    }

    // Request full history sync (requestSync queues if still connecting).
    _relayService?.requestSync(childId);
    if (kDebugMode) print('[AppSession] triggerSync: sync requested for $childId');
  }

  /// Removes the linked child account.
  void unlinkChild() {
    _linkedChildName = null;
    _linkedChildren.clear();
    _selectedChildId = null;
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
