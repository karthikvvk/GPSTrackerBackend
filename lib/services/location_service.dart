import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpstracking/data/api_service.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/data/models.dart';

/// Location tracking service - handles GPS polling, server sync, and offline backup
class LocationService {
  final ApiService _apiService;
  final String userId;

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  bool _busy = false;
  bool _serverUp = false;
  bool _lastServerUp = false;

  /// Callback for status updates
  void Function(String message)? onStatusUpdate;

  /// Callback for location updates
  void Function(CoordinateLog log)? onLocationUpdate;

  LocationService({
    required this.userId,
    ApiService? apiService,
  }) : _apiService = apiService ?? ApiService();

  bool get isTracking => _isTracking;
  bool get isServerUp => _serverUp;

  /// Request location permissions
  Future<bool> requestPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _log('Location services disabled');
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _log('Location permission denied');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _log('Location permission permanently denied');
      return false;
    }

    return true;
  }

  /// Start the tracking loop
  Future<void> startTracking() async {
    if (_isTracking) return;

    final hasPermission = await requestPermissions();
    if (!hasPermission) return;

    _isTracking = true;
    _log('🔄 Started tracking...');

    // Subscribe to a persistent position stream – keeps a single GPS
    // context alive so the location icon stays steady (no flicker).
    // AndroidSettings with intervalDuration ensures periodic delivery
    // even when stationary (generic LocationSettings won't push updates
    // on Android if distanceFilter is 0 and device doesn't move).
    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
    );

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (position) => _handlePosition(position),
      onError: (e) => _log('📍 Stream error: $e'),
      cancelOnError: false,
    );
  }

  /// Stop tracking
  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _log('⏹️ Stopped tracking');
  }

  /// Handle an incoming position from the stream
  Future<void> _handlePosition(Position position) async {
    if (!_isTracking) return;
    // Guard against re-entrant processing when async work is slow
    if (_busy) return;
    _busy = true;

    try {
      // Check server status
      await _checkServerStatus();

      // If server just came back online, sync backup logs
      if (_serverUp && !_lastServerUp) {
        await _syncBackupLogs();
      }
      _lastServerUp = _serverUp;

      // Create coordinate log
      final now = DateTime.now().toUtc().toIso8601String();
      final coord = CoordinateLog(
        xCord: position.latitude,
        yCord: position.longitude,
        loggedTime: now,
        userId: userId,
        synced: _serverUp,
      );

      // Handle based on server status
      if (_serverUp) {
        final sent = await _apiService.sendCoords(userId, [coord]);
        if (sent) {
          await LocalDb.insertLog(coord);
          _log(
              '✅ Sent: (${coord.xCord.toStringAsFixed(4)}, ${coord.yCord.toStringAsFixed(4)})');
        } else {
          await _saveOffline(coord);
        }
      } else {
        await _saveOffline(coord);
      }

      onLocationUpdate?.call(coord);
    } catch (e) {
      _log('❌ Error: $e');
    } finally {
      _busy = false;
    }
  }

  /// Check if server is online
  Future<void> _checkServerStatus() async {
    _serverUp = await _apiService.checkServerStatus();
    _log(_serverUp ? '🟢 Server online' : '🔴 Server offline');
  }

  /// Save coordinate to local backup (offline mode)
  Future<void> _saveOffline(CoordinateLog coord) async {
    await LocalDb.insertBackupLog(coord);
    await LocalDb.insertLog(coord);
    _log(
        '💾 Saved offline: (${coord.xCord.toStringAsFixed(4)}, ${coord.yCord.toStringAsFixed(4)})');
  }

  /// Sync backup logs when server comes back online
  Future<void> _syncBackupLogs() async {
    final backupLogs = await LocalDb.getBackupLogs();
    if (backupLogs.isEmpty) return;

    _log('🔄 Syncing ${backupLogs.length} backup logs...');

    final success = await _apiService.sendCoords(userId, backupLogs);
    if (success) {
      await LocalDb.clearBackupLogs();
      _log('✅ Synced ${backupLogs.length} backup logs');
    } else {
      _log('❌ Failed to sync backup logs');
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[LocationService] $message');
    }
    onStatusUpdate?.call(message);
  }

  void dispose() {
    // Clear callbacks BEFORE stopping to avoid calling setState on
    // a defunct widget during the stopTracking _log call.
    onStatusUpdate = null;
    onLocationUpdate = null;
    stopTracking();
    _apiService.dispose();
  }
}
