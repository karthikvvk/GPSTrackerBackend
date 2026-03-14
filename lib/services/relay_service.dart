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
  String? _pendingChildId;        // child to subscribe after connect (parent mode)
  String? _pendingSyncChildId;    // child to sync after connect (parent mode)
  String? _pendingSyncFromTimestamp; // incremental sync start point

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

  /// Sync batch responses (parent receives batches of historical coords + done flag)
  final _syncBatchController =
      StreamController<({List<Map<String, dynamic>> coords, bool done})>.broadcast();
  Stream<({List<Map<String, dynamic>> coords, bool done})> get syncBatchStream =>
      _syncBatchController.stream;

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
      // Render free-tier can take 30-60s on cold start — give it plenty of time.
      'connectTimeout': 60000,      // 60 s to establish the connection
      'timeout': 60000,             // 60 s general response timeout
      'reconnection': true,
      'reconnectionAttempts': 10,   // try up to 10 times before giving up
      'reconnectionDelay': 2000,    // start at 2 s between retries
      'reconnectionDelayMax': 10000,// cap at 10 s
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
        // Fire pending DB sync request if queued
        if (_pendingSyncChildId != null) {
          _socket!.emit('parent_request_sync', {
            'childId': _pendingSyncChildId,
            'fromTimestamp': _pendingSyncFromTimestamp,
          });
          if (kDebugMode) print('[RelayService] Sync emitted (deferred) from=$_pendingSyncFromTimestamp');
          _pendingSyncChildId = null;
          _pendingSyncFromTimestamp = null;
        }
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

    // Parent requests a DB sync: stream all records after fromTimestamp
    _socket?.on('sync_request', (data) async {
      final parentSid = data['parentSid'] as String;
      final fromTimestamp = (data['fromTimestamp'] as String?) ?? '';

      if (kDebugMode) {
        // Diagnostic: show total records and actual timestamp range in DB
        final allLogs = await LocalDb.getAllLogs();
        print('[Sync] DB total records: ${allLogs.length}');
        if (allLogs.isNotEmpty) {
          print('[Sync] DB earliest: ${allLogs.first.loggedTime}');
          print('[Sync] DB latest:   ${allLogs.last.loggedTime}');
        }
        print('[Sync] Query from=$fromTimestamp (no cutoff)');
      }

      final logs = await LocalDb.getLogsAfter(fromTimestamp);

      if (kDebugMode) {
        print('[Sync] getLogsAfter returned: ${logs.length} records');
      }

      if (logs.isEmpty) {
        _socket?.emit('child_sync_batch',
            {'parentSid': parentSid, 'coords': [], 'done': true});
        return;
      }

      const batchSize = 200;
      for (var i = 0; i < logs.length; i += batchSize) {
        final end =
            (i + batchSize < logs.length) ? i + batchSize : logs.length;
        final batch = logs.sublist(i, end);
        final done = end == logs.length;

        _socket?.emit('child_sync_batch', {
          'parentSid': parentSid,
          'coords': batch.map((l) => l.toJson()).toList(),
          'done': done,
        });

        // Small yield between batches to avoid saturating the event loop
        await Future.delayed(const Duration(milliseconds: 10));
      }

      if (kDebugMode) {
        print('[RelayService] Sync complete: ${logs.length} records sent');
      }
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

    // Historical sync batch from child (streaming DB data)
    _socket?.on('sync_batch', (data) {
      final rawCoords = data['coords'] as List? ?? [];
      final coords = rawCoords.cast<Map<String, dynamic>>();
      final done = data['done'] as bool? ?? false;
      _syncBatchController.add((coords: coords, done: done));
      if (kDebugMode) {
        print('[RelayService] sync_batch received: ${coords.length} records, done=$done');
      }
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

  /// Request an incremental DB sync from the child.
  ///
  /// The child will stream all records with logged_time > [fromTimestamp]
  /// up to (now - 1 minute) back to this parent in batches.
  /// Pass null for [fromTimestamp] to request the full history.
  /// If the socket is not yet connected, the request is queued and fires
  /// from onConnect — no data is lost.
  void requestSync(String childId, {String? fromTimestamp}) {
    if (kDebugMode) print('[RelayService] requestSync connected=$_connected from=$fromTimestamp');
    if (!_connected || _socket == null) {
      // Queue it — onConnect will fire it once the socket opens
      _pendingSyncChildId = childId;
      _pendingSyncFromTimestamp = fromTimestamp;
      if (kDebugMode) print('[RelayService] Sync queued (not yet connected)');
      return;
    }
    _socket!.emit('parent_request_sync', {
      'childId': childId,
      'fromTimestamp': fromTimestamp,
    });
    if (kDebugMode) print('[RelayService] Sync emitted immediately from=$fromTimestamp');
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
    _syncBatchController.close();
  }
}
