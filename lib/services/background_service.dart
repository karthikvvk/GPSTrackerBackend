import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/data/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Background service for persistent location tracking.
///
/// In the relay architecture, the background service only writes to local
/// SQLite — no server writes. Live relay happens via [RelayService] in the
/// foreground isolate only (WebSocket connections don't survive isolate
/// boundaries).
@pragma('vm:entry-point')
class BackgroundService {
  static const String _channelId = 'gpstracker_channel';
  static const String _channelName = 'GPS Tracker Background';
  static const int _notificationId = 888;

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Check if platform supports background service
  static bool get _isSupported => Platform.isAndroid || Platform.isIOS;

  /// Initialize the background service
  static Future<void> initialize() async {
    if (!_isSupported) {
      if (kDebugMode) {
        print(
            '[BackgroundService] Skipping init - not supported on this platform');
      }
      return;
    }

    // Initialize notifications
    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'GPS Tracker location tracking service',
      importance: Importance.low,
    );

    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Configure background service
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: 'GPS Tracker',
        initialNotificationContent: 'Ready to track',
        foregroundServiceNotificationId: _notificationId,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
    );
  }

  /// Start background tracking
  static Future<void> startService(String userId) async {
    if (!_isSupported) return;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bg_user_id', userId);
    
    await _service.startService();
    _service.invoke('setUserId', {'userId': userId});
  }

  /// Stop background tracking
  static Future<void> stopService() async {
    if (!_isSupported) return;
    _service.invoke('stopService');
  }

  /// Check if service is running
  static Future<bool> isRunning() async {
    if (!_isSupported) return false;
    return await _service.isRunning();
  }

  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('bg_user_id');
    
    bool isTracking = false;
    bool busy = false;
    StreamSubscription<Position>? positionSub;

    // Listen for commands
    service.on('setUserId').listen((event) {
      userId = event?['userId'] as String?;
      prefs.setString('bg_user_id', userId ?? '');
      if (kDebugMode) {
        print('[BackgroundService] User ID set: $userId');
      }
    });

    service.on('stopService').listen((event) {
      isTracking = false;
      positionSub?.cancel();
      service.stopSelf();
    });

    // Update notification
    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: 'GPS Tracker Active',
        content: 'Tracking your location in the background',
      );
    }

    // Wait for user ID to be set
    await Future.delayed(const Duration(milliseconds: 500));

    isTracking = true;

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: const Duration(seconds: 1),
    );

    positionSub = Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen((position) async {
      if (!isTracking || userId == null) return;
      if (busy) return;
      busy = true;

      try {
        final now = DateTime.now().toUtc().toIso8601String();
        final coord = CoordinateLog(
          xCord: position.latitude,
          yCord: position.longitude,
          loggedTime: now,
          userId: userId,
          synced: true,
        );

        // Save to local SQLite only (no server writes)
        await LocalDb.insertLog(coord);

        // Update notification with latest position
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'GPS Tracker Active',
            content:
                'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          );
        }

        // Send update to UI (foreground isolate picks this up for relay)
        service.invoke('update', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'time': now,
        });
      } catch (e) {
        if (kDebugMode) {
          print('[BackgroundService] Error: $e');
        }
      } finally {
        busy = false;
      }
    }, onError: (e) {
      if (kDebugMode) {
        print('[BackgroundService] Stream error: $e');
      }
    }, cancelOnError: false);
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
}
