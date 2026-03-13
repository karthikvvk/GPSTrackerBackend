import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/services/relay_service.dart';

/// Location tracking service - handles GPS polling and local storage.
///
/// All coordinates are stored locally in SQLite. If a [RelayService] is
/// attached, each new position is also pushed to the relay for real-time
/// streaming to subscribed parents.  No server-side DB writes happen.
class LocationService {
  final String userId;
  RelayService? _relayService;

  StreamSubscription<Position>? _positionSubscription;
  bool _isTracking = false;
  bool _busy = false;

  /// Callback for status updates
  void Function(String message)? onStatusUpdate;

  /// Callback for location updates
  void Function(CoordinateLog log)? onLocationUpdate;

  LocationService({required this.userId});

  bool get isTracking => _isTracking;

  /// Attach (or detach) a relay service for real-time streaming to parents.
  /// Pass null to detach without closing the socket.
  void attachRelay(RelayService? relay) {
    _relayService = relay;
  }

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
    if (_busy) return;
    _busy = true;

    try {
      final now = DateTime.now().toUtc().toIso8601String();
      final coord = CoordinateLog(
        xCord: position.latitude,
        yCord: position.longitude,
        loggedTime: now,
        userId: userId,
        synced: true,
      );

      // 1. Always save to local SQLite (primary storage)
      await LocalDb.insertLog(coord);

      // 2. Push to relay for live streaming (lightweight, no server DB write)
      _relayService?.pushLocation(coord);

      _log(
          '📍 (${coord.xCord.toStringAsFixed(4)}, ${coord.yCord.toStringAsFixed(4)})');

      onLocationUpdate?.call(coord);
    } catch (e) {
      _log('❌ Error: $e');
    } finally {
      _busy = false;
    }
  }

  void _log(String message) {
    if (kDebugMode) {
      print('[LocationService] $message');
    }
    onStatusUpdate?.call(message);
  }

  void dispose() {
    onStatusUpdate = null;
    onLocationUpdate = null;
    stopTracking();
  }
}
