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

  Timer? _trackingTimer;
  bool _isTracking = false;
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

    // Start the timer for periodic tracking
    _trackingTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _trackingLoop(),
    );

    // Run immediately
    await _trackingLoop();
  }

  /// Stop tracking
  void stopTracking() {
    _isTracking = false;
    _trackingTimer?.cancel();
    _trackingTimer = null;
    _log('⏹️ Stopped tracking');
  }

  /// Main tracking loop - mirrors TrackerLoop.kt logic
  Future<void> _trackingLoop() async {
    if (!_isTracking) return;

    try {
      // Get current location
      final position = await _getCurrentLocation();
      if (position == null) return;

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
          _log('✅ Sent: (${coord.xCord.toStringAsFixed(4)}, ${coord.yCord.toStringAsFixed(4)})');
        } else {
          await _saveOffline(coord);
        }
      } else {
        await _saveOffline(coord);
      }

      onLocationUpdate?.call(coord);
    } catch (e) {
      _log('❌ Error: $e');
    }
  }

  /// Get current GPS position
  Future<Position?> _getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );
    } catch (e) {
      _log('📍 Location error: $e');
      return null;
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
    _log('💾 Saved offline: (${coord.xCord.toStringAsFixed(4)}, ${coord.yCord.toStringAsFixed(4)})');
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
    stopTracking();
    _apiService.dispose();
  }
}
