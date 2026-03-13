import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/utils/settings.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// WebSocket relay service for real-time communication between child and parent.
///
/// The server acts as a broker — no coordinate data is stored on the server.
/// - **Child mode**: Registers with the server, pushes live locations,
///   responds to history requests from parents.
/// - **Parent mode**: Subscribes to a child's live feed, requests history.
class RelayService {
  io.Socket? _socket;
  String? _userId;
  bool _isChild = false;
  bool _connected = false;
  String? _pendingChildId; // child to subscribe after connect (parent mode)

  // --- Streams for consumers ---

  /// Live location updates (parent receives from child via relay)
  final _liveLocationController = StreamController<CoordinateLog>.broadcast();
  Stream<CoordinateLog> get liveLocationStream =>
      _liveLocationController.stream;

  /// Child online/offline status changes
  final _childStatusController = StreamController<bool>.broadcast();
  Stream<bool> get childStatusStream => _childStatusController.stream;

  /// History data responses
  final _historyDataController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get historyDataStream =>
      _historyDataController.stream;

  /// History dates responses
  final _historyDatesController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get historyDatesStream =>
      _historyDatesController.stream;

  bool get isConnected => _connected;

  // =========================================================================
  // Connection Management
  // =========================================================================

  /// Connect to the relay server.
  ///
  /// [userId] — the current user's ID.
  /// [isChild] — true if this device is a child (tracked), false if parent.
  Future<void> connect({
    required String userId,
    required bool isChild,
  }) async {
    _userId = userId;
    _isChild = isChild;

    final settings = await Settings.instance;
    final baseUrl = settings.backendUrl;

    _socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': true,
    });

    _socket!.onConnect((_) {
      _connected = true;
      if (kDebugMode) print('[RelayService] Connected');

      if (_isChild) {
        _registerAsChild();
      } else if (_pendingChildId != null) {
        // Subscribe now that the socket is actually open
        _socket!.emit('parent_subscribe', {'childId': _pendingChildId});
        if (kDebugMode) print('[RelayService] Subscribed to child: $_pendingChildId');
      }
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      if (kDebugMode) print('[RelayService] Disconnected');
    });

    _socket!.onConnectError((err) {
      _connected = false;
      if (kDebugMode) print('[RelayService] Connection error: $err');
    });

    _socket!.onReconnect((_) {
      _connected = true;
      if (kDebugMode) print('[RelayService] Reconnected');
      if (_isChild) {
        _registerAsChild();
      } else if (_pendingChildId != null) {
        _socket!.emit('parent_subscribe', {'childId': _pendingChildId});
      }
    });

    // Set up event listeners based on role
    if (_isChild) {
      _setupChildListeners();
    } else {
      _setupParentListeners();
    }

    _socket!.connect();
  }

  /// Disconnect from the relay server.
  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _userId = null;
  }

  // =========================================================================
  // Child Mode
  // =========================================================================

  void _registerAsChild() {
    _socket?.emit('child_register', {'userId': _userId});
  }

  void _setupChildListeners() {
    // Server asks child for history data for a specific date
    _socket?.on('history_request', (data) async {
      final date = data['date'] as String;
      final requestId = data['requestId'] as String;
      final parentSid = data['parentSid'] as String;

      if (kDebugMode) print('[RelayService] History request for $date');

      // Fetch from local DB
      final logs = await LocalDb.getLogsByDate(date);
      final coordsJson = logs.map((l) => l.toJson()).toList();

      _socket?.emit('child_history_response', {
        'requestId': requestId,
        'parentSid': parentSid,
        'date': date,
        'coords': coordsJson,
      });
    });

    // Server asks child for available dates
    _socket?.on('dates_request', (data) async {
      final requestId = data['requestId'] as String;
      final parentSid = data['parentSid'] as String;

      if (kDebugMode) print('[RelayService] Dates request');

      final dates = await LocalDb.getAllDates();

      _socket?.emit('child_dates_response', {
        'requestId': requestId,
        'parentSid': parentSid,
        'dates': dates,
      });
    });
  }

  /// Push a location update to the server for relay to subscribed parents.
  void pushLocation(CoordinateLog coord) {
    if (!_connected || !_isChild || _socket == null) return;

    _socket!.emit('child_location_update', {
      'userId': _userId,
      'x_cord': coord.xCord,
      'y_cord': coord.yCord,
      'logged_time': coord.loggedTime,
    });
  }

  // =========================================================================
  // Parent Mode
  // =========================================================================

  void _setupParentListeners() {
    // Receive live location from child via relay
    _socket?.on('live_location', (data) {
      final coord = CoordinateLog(
        xCord: (data['x_cord'] as num).toDouble(),
        yCord: (data['y_cord'] as num).toDouble(),
        loggedTime: data['logged_time'] as String,
        userId: data['childId'] as String?,
        synced: true,
      );
      _liveLocationController.add(coord);
    });

    // Child came online
    _socket?.on('child_online', (data) {
      if (kDebugMode) print('[RelayService] Child online: ${data['childId']}');
      _childStatusController.add(true);
    });

    // Child went offline
    _socket?.on('child_offline', (data) {
      if (kDebugMode) print('[RelayService] Child offline: ${data['childId']}');
      _childStatusController.add(false);
    });

    // Subscription confirmation
    _socket?.on('subscribed', (data) {
      final online = data['online'] as bool;
      _childStatusController.add(online);
    });

    // History data from child
    _socket?.on('history_data', (data) {
      _historyDataController.add(data as Map<String, dynamic>);
    });

    // History dates from child
    _socket?.on('history_dates', (data) {
      final dates = (data['dates'] as List).cast<String>();
      _historyDatesController.add(dates);
    });
  }

  /// Subscribe to a child's live location stream.
  /// Stores [childId] so it can be re-sent after reconnects.
  void subscribeToChild(String childId) {
    _pendingChildId = childId;
    if (_connected && _socket != null) {
      _socket!.emit('parent_subscribe', {'childId': childId});
      if (kDebugMode) print('[RelayService] Subscribed to child: $childId');
    }
    // else: onConnect will subscribe once the socket opens
  }

  /// Unsubscribe from the current child.
  void unsubscribeFromChild() {
    if (!_connected || _socket == null) return;
    _socket!.emit('parent_unsubscribe', {});
  }

  /// Request history data for a specific date from the child.
  void requestHistory(String childId, String date) {
    if (!_connected || _socket == null) return;
    _socket!.emit('parent_request_history', {
      'childId': childId,
      'date': date,
    });
  }

  /// Request available history dates from the child.
  void requestDates(String childId) {
    if (!_connected || _socket == null) return;
    _socket!.emit('parent_request_dates', {
      'childId': childId,
    });
  }

  // =========================================================================
  // Cleanup
  // =========================================================================

  void dispose() {
    disconnect();
    _liveLocationController.close();
    _childStatusController.close();
    _historyDataController.close();
    _historyDatesController.close();
  }
}
