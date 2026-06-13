import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/utils/settings.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class RelayService {
  io.Socket? _socket;
  String? _userId; // current user's own id
  bool _isChild = false;
  bool _connected = false;

  /// Parent mode: set of childIds currently being watched (multi-room)
  final Set<String> _watchedChildIds = {};

  String? _pendingSyncChildId;
  String? _pendingSyncFromTimestamp;

  // --- Streams ---
  final _liveLocationController = StreamController<CoordinateLog>.broadcast();
  Stream<CoordinateLog> get liveLocationStream =>
      _liveLocationController.stream;

  final _childStatusController = StreamController<Map<String, dynamic>>.broadcast();
  /// Emits `{ 'childId': String, 'online': bool }` maps.
  Stream<Map<String, dynamic>> get childStatusStream =>
      _childStatusController.stream;

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

  /// All currently watched child IDs (read-only view).
  Set<String> get watchedChildIds => Set.unmodifiable(_watchedChildIds);

  // =========================================================================
  // Connection
  // =========================================================================

  Future<void> connect({
    required String userId, // always the CURRENT user's id
    required bool isChild,
    /// Deprecated for parent mode — use [subscribeToChild] after connect().
    /// Still accepted for back-compat.
    String? childId,
  }) async {
    _userId = userId;
    _isChild = isChild;

    // -----------------------------------------------------------------------
    // GUARD: parent must never use their own id as childId
    // -----------------------------------------------------------------------
    if (!isChild && childId != null) {
      assert(
          childId != userId,
          '[RelayService] BUG: childId == userId ($userId). '
          'You are passing the parent\'s own id as childId. '
          'Pass the looked-up child\'s user_id instead.');

      if (childId == userId) {
        if (kDebugMode) {
          print(
              '[RelayService] ❌ BLOCKED connect: childId equals own userId');
        }
        return;
      }
      // Queue this child to be subscribed once connected
      _watchedChildIds.add(childId);
    }

    if (kDebugMode) {
      print('[RelayService] Connecting...');
      print('[RelayService]   role    = ${isChild ? "CHILD" : "PARENT"}');
      print('[RelayService]   userId  = $userId');
      if (!isChild) print('[RelayService]   watchedChildren = $_watchedChildIds');
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
      // Re-subscribe to ALL watched children (handles reconnects)
      for (final cid in _watchedChildIds) {
        _emitSubscribe(cid);
      }
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
    _watchedChildIds.clear();
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
      if (kDebugMode) {
        print('[RelayService] Sync complete: ${logs.length} records sent');
      }
    });
  }

  void pushLocation(CoordinateLog coord) {
    if (!_connected || !_isChild || _socket == null) return;
    _socket!.emit('child_location_update', {
      'userId': _userId,
      'x_cord': coord.xCord,
      'y_cord': coord.yCord,
      // Send epoch-ms integer instead of ISO string: 13 bytes vs 27 bytes.
      'ts': DateTime.parse(coord.loggedTime).millisecondsSinceEpoch,
    });
  }

  // =========================================================================
  // Parent Mode
  // =========================================================================

  void _emitSubscribe(String childId) {
    if (kDebugMode) {
      print('[RelayService] Subscribing to child: $childId');
      print('[RelayService]   (parent userId=$_userId)');
    }
    _socket!.emit('parent_subscribe', {'childId': childId});
  }

  /// Subscribe to an additional child (additive — does not drop existing subs).
  void subscribeToChild(String childId) {
    assert(childId != _userId,
        '[RelayService] BUG: trying to subscribe to own userId as child');
    if (childId == _userId) return;
    _watchedChildIds.add(childId);
    if (_connected && _socket != null) {
      _emitSubscribe(childId);
    }
  }

  /// Remove a single child subscription without affecting others.
  void unsubscribeFromChild(String childId) {
    _watchedChildIds.remove(childId);
    if (!_connected || _socket == null) return;
    _socket!.emit('parent_unsubscribe_child', {'childId': childId});
  }

  /// Unsubscribe from ALL children and clear the watch set.
  void unsubscribeFromAll() {
    if (_connected && _socket != null) {
      _socket!.emit('parent_unsubscribe', {});
    }
    _watchedChildIds.clear();
  }

  void _setupParentListeners() {
    _socket?.on('live_location', (data) {
      // Convert epoch-ms integer back to ISO string for DB storage.
      final tsMs = (data['ts'] as num).toInt();
      final loggedTime =
          DateTime.fromMillisecondsSinceEpoch(tsMs, isUtc: true)
              .toIso8601String();
      final coord = CoordinateLog(
        xCord: (data['x_cord'] as num).toDouble(),
        yCord: (data['y_cord'] as num).toDouble(),
        loggedTime: loggedTime,
        userId: data['childId'] as String?,
        synced: true,
      );
      _liveLocationController.add(coord);
    });

    _socket?.on('child_online', (data) {
      final childId = data['childId'] as String?;
      if (kDebugMode) print('[RelayService] Child online: $childId');
      _childStatusController.add({'childId': childId, 'online': true});
    });

    _socket?.on('child_offline', (data) {
      final childId = data['childId'] as String?;
      if (kDebugMode) print('[RelayService] Child offline: $childId');
      _childStatusController.add({'childId': childId, 'online': false});
    });

    _socket?.on('subscribed', (data) {
      final childId = data['childId'] as String?;
      final online = data['online'] as bool;
      if (kDebugMode) {
        print('[RelayService] Subscribed confirmed: childId=$childId, online=$online');
      }
      _childStatusController.add({'childId': childId, 'online': online});
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
      if (kDebugMode) {
        print(
            '[RelayService] sync_batch: ${coords.length} records, done=$done');
      }
      _syncBatchController.add((coords: coords, done: done));
    });
  }

  // =========================================================================
  // Parent Public API (back-compat)
  // =========================================================================

  void requestHistory(String childId, String date) {
    if (!_connected || _socket == null) return;
    _socket!.emit('parent_request_history', {'childId': childId, 'date': date});
  }

  void requestDates(String childId) {
    if (!_connected || _socket == null) return;
    _socket!.emit('parent_request_dates', {'childId': childId});
  }

  void requestSync(String childId, {String? fromTimestamp}) {
    if (kDebugMode) {
      print(
          '[RelayService] requestSync connected=$_connected from=$fromTimestamp');
    }
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
