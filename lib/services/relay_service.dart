import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/utils/settings.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class RelayService {
  io.Socket? _socket;
  String? _userId; // parent's own user_id
  String? _childId; // the child we are tracking (parent mode only)
  bool _isChild = false;
  bool _connected = false;

  String? _pendingSyncChildId;
  String? _pendingSyncFromTimestamp;

  // --- Streams ---
  final _liveLocationController = StreamController<CoordinateLog>.broadcast();
  Stream<CoordinateLog> get liveLocationStream =>
      _liveLocationController.stream;

  final _childStatusController = StreamController<bool>.broadcast();
  Stream<bool> get childStatusStream => _childStatusController.stream;

  final _historyDataController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get historyDataStream =>
      _historyDataController.stream;

  final _historyDatesController = StreamController<List<String>>.broadcast();
  Stream<List<String>> get historyDatesStream => _historyDatesController.stream;

  final _syncBatchController = StreamController<
      ({List<Map<String, dynamic>> coords, bool done})>.broadcast();
  Stream<({List<Map<String, dynamic>> coords, bool done})>
      get syncBatchStream => _syncBatchController.stream;

  bool get isConnected => _connected;

  // =========================================================================
  // Connection
  // =========================================================================

  Future<void> connect({
    required String userId, // always the CURRENT user's id
    required bool isChild,
    String? childId, // REQUIRED when isChild=false — the child to track
  }) async {
    _userId = userId;
    _isChild = isChild;

    // -----------------------------------------------------------------------
    // GUARD: parent must always provide a childId that differs from their own
    // -----------------------------------------------------------------------
    if (!isChild) {
      assert(childId != null,
          '[RelayService] childId must be provided in parent mode');
      assert(
          childId != userId,
          '[RelayService] BUG: childId == userId ($userId). '
          'You are passing the parent\'s own id as childId. '
          'Pass the looked-up child\'s user_id instead.');

      if (childId == null || childId == userId) {
        if (kDebugMode) {
          print(
              '[RelayService] ❌ BLOCKED connect: childId is null or equals own userId');
          print('[RelayService]    userId  (parent) = $userId');
          print('[RelayService]    childId (target) = $childId');
          print(
              '[RelayService]    Fix: pass the child\'s user_id from /auth/lookup');
        }
        return; // abort — do not connect with wrong ids
      }

      _childId = childId;
    }

    if (kDebugMode) {
      print('[RelayService] Connecting...');
      print('[RelayService]   role    = ${isChild ? "CHILD" : "PARENT"}');
      print('[RelayService]   userId  = $userId');
      if (!isChild) print('[RelayService]   childId = $_childId');
    }

    final settings = await Settings.instance;
    final baseUrl = settings.backendUrl;

    _socket = io.io(baseUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': true,
      'connectTimeout': 60000,
      'timeout': 60000,
      'reconnection': true,
      'reconnectionAttempts': 10,
      'reconnectionDelay': 2000,
      'reconnectionDelayMax': 10000,
    });

    if (_isChild) {
      _setupChildListeners();
    } else {
      _setupParentListeners();
    }

    _socket!.onConnect((_) {
      _connected = true;
      if (kDebugMode) print('[RelayService] ✅ Connected (sid=${_socket?.id})');
      _onConnected();
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
      if (kDebugMode) print('[RelayService] Reconnected (sid=${_socket?.id})');
      _onConnected(); // re-register/re-subscribe on reconnect
    });

    _socket!.connect();
  }

  /// Called on every connect and reconnect — single source of truth.
  void _onConnected() {
    if (_isChild) {
      _registerAsChild();
    } else {
      _subscribeNow();
      // Fire pending sync if queued
      if (_pendingSyncChildId != null) {
        _emitSync(_pendingSyncChildId!, _pendingSyncFromTimestamp);
        _pendingSyncChildId = null;
        _pendingSyncFromTimestamp = null;
      }
    }
  }

  void disconnect() {
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _userId = null;
    _childId = null;
  }

  // =========================================================================
  // Child Mode
  // =========================================================================

  void _registerAsChild() {
    if (kDebugMode) print('[RelayService] Registering as child: $_userId');
    _socket?.emit('child_register', {'userId': _userId});
  }

  void _setupChildListeners() {
    _socket?.on('history_request', (data) async {
      final date = data['date'] as String;
      final requestId = data['requestId'] as String;
      final parentSid = data['parentSid'] as String;
      if (kDebugMode) print('[RelayService] History request for $date');
      final logs = await LocalDb.getLogsByDate(date);
      _socket?.emit('child_history_response', {
        'requestId': requestId,
        'parentSid': parentSid,
        'date': date,
        'coords': logs.map((l) => l.toJson()).toList(),
      });
    });

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

    _socket?.on('sync_request', (data) async {
      final parentSid = data['parentSid'] as String;
      final fromTimestamp = (data['fromTimestamp'] as String?) ?? '';
      if (kDebugMode) {
        final allLogs = await LocalDb.getAllLogs();
        print('[Sync] DB total: ${allLogs.length}, from=$fromTimestamp');
      }
      final logs = await LocalDb.getLogsAfter(fromTimestamp);
      if (kDebugMode) print('[Sync] Sending ${logs.length} records');
      if (logs.isEmpty) {
        _socket?.emit('child_sync_batch',
            {'parentSid': parentSid, 'coords': [], 'done': true});
        return;
      }
      const batchSize = 200;
      for (var i = 0; i < logs.length; i += batchSize) {
        final end = (i + batchSize < logs.length) ? i + batchSize : logs.length;
        final batch = logs.sublist(i, end);
        _socket?.emit('child_sync_batch', {
          'parentSid': parentSid,
          'coords': batch.map((l) => l.toJson()).toList(),
          'done': end == logs.length,
        });
        await Future.delayed(const Duration(milliseconds: 10));
      }
      if (kDebugMode)
        print('[RelayService] Sync complete: ${logs.length} records sent');
    });
  }

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

  void _subscribeNow() {
    if (_childId == null) return;
    if (kDebugMode) {
      print('[RelayService] Subscribing to child: $_childId');
      print('[RelayService]   (parent userId=$_userId)');
    }
    _socket!.emit('parent_subscribe', {'childId': _childId});
  }

  void _setupParentListeners() {
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

    _socket?.on('child_online', (data) {
      if (kDebugMode) print('[RelayService] Child online: ${data['childId']}');
      _childStatusController.add(true);
    });

    _socket?.on('child_offline', (data) {
      if (kDebugMode) print('[RelayService] Child offline: ${data['childId']}');
      _childStatusController.add(false);
    });

    _socket?.on('subscribed', (data) {
      final online = data['online'] as bool;
      if (kDebugMode)
        print('[RelayService] Subscribed confirmed, child online=$online');
      _childStatusController.add(online);
    });

    _socket?.on('history_data', (data) {
      _historyDataController.add(data as Map<String, dynamic>);
    });

    _socket?.on('history_dates', (data) {
      final dates = (data['dates'] as List).cast<String>();
      _historyDatesController.add(dates);
    });

    _socket?.on('sync_batch', (data) {
      final rawCoords = data['coords'] as List? ?? [];
      final coords = rawCoords.cast<Map<String, dynamic>>();
      final done = data['done'] as bool? ?? false;
      if (kDebugMode)
        print(
            '[RelayService] sync_batch: ${coords.length} records, done=$done');
      _syncBatchController.add((coords: coords, done: done));
    });
  }

  // =========================================================================
  // Parent Public API
  // =========================================================================

  /// Subscribe to a different child (hot-swap).
  void subscribeToChild(String newChildId) {
    assert(newChildId != _userId,
        '[RelayService] BUG: trying to subscribe to own userId as child');
    _childId = newChildId;
    if (_connected && _socket != null) {
      _subscribeNow();
    }
  }

  void unsubscribeFromChild() {
    if (!_connected || _socket == null) return;
    _socket!.emit('parent_unsubscribe', {});
  }

  void requestHistory(String childId, String date) {
    if (!_connected || _socket == null) return;
    _socket!.emit('parent_request_history', {'childId': childId, 'date': date});
  }

  void requestDates(String childId) {
    if (!_connected || _socket == null) return;
    _socket!.emit('parent_request_dates', {'childId': childId});
  }

  void requestSync(String childId, {String? fromTimestamp}) {
    if (kDebugMode)
      print(
          '[RelayService] requestSync connected=$_connected from=$fromTimestamp');
    if (!_connected || _socket == null) {
      _pendingSyncChildId = childId;
      _pendingSyncFromTimestamp = fromTimestamp;
      if (kDebugMode) print('[RelayService] Sync queued');
      return;
    }
    _emitSync(childId, fromTimestamp);
  }

  void _emitSync(String childId, String? fromTimestamp) {
    _socket!.emit('parent_request_sync', {
      'childId': childId,
      'fromTimestamp': fromTimestamp,
    });
    if (kDebugMode) print('[RelayService] Sync emitted from=$fromTimestamp');
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
