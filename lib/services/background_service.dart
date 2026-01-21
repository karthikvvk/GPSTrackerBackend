import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:gpstracking/data/api_service.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/data/models.dart';

/// Background service for persistent location tracking
class BackgroundService {
  static const String _channelId = 'gpstracker_channel';
  static const String _channelName = 'GPS Tracker Background';
  static const int _notificationId = 888;

  static final FlutterBackgroundService _service = FlutterBackgroundService();

  /// Check if platform supports background service
  static bool get _isSupported => Platform.isAndroid || Platform.isIOS;

  /// Initialize the background service
  static Future<void> initialize() async {
    // Background service only works on Android and iOS
    if (!_isSupported) {
      if (kDebugMode) {
        print('[BackgroundService] Skipping init - not supported on this platform');
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

  /// Entry point for background service
  @pragma('vm:entry-point')
  static Future<void> _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    String? userId;
    bool isTracking = false;
    Timer? trackingTimer;
    final apiService = ApiService();

    // Listen for commands
    service.on('setUserId').listen((event) {
      userId = event?['userId'] as String?;
      if (kDebugMode) {
        print('[BackgroundService] User ID set: $userId');
      }
    });

    service.on('stopService').listen((event) {
      isTracking = false;
      trackingTimer?.cancel();
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

    // Wait a bit for user ID to be set
    await Future.delayed(const Duration(milliseconds: 500));

    isTracking = true;

    // Start tracking loop
    trackingTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!isTracking || userId == null) return;

      try {
        // Check location permission
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          return;
        }

        // Get current position
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        // Check server status
        final serverUp = await apiService.checkServerStatus();

        // Create log
        final now = DateTime.now().toUtc().toIso8601String();
        final coord = CoordinateLog(
          xCord: position.latitude,
          yCord: position.longitude,
          loggedTime: now,
          userId: userId,
          synced: serverUp,
        );

        // Handle based on server status
        if (serverUp) {
          final sent = await apiService.sendCoords(userId!, [coord]);
          if (sent) {
            await LocalDb.insertLog(coord);
          } else {
            await LocalDb.insertBackupLog(coord);
            await LocalDb.insertLog(coord);
          }
        } else {
          await LocalDb.insertBackupLog(coord);
          await LocalDb.insertLog(coord);
        }

        // Update notification with latest position
        if (service is AndroidServiceInstance) {
          service.setForegroundNotificationInfo(
            title: 'GPS Tracker Active',
            content:
                'Location: ${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)}',
          );
        }

        // Send update to UI
        service.invoke('update', {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'time': now,
          'serverUp': serverUp,
        });
      } catch (e) {
        if (kDebugMode) {
          print('[BackgroundService] Error: $e');
        }
      }
    });
  }

  @pragma('vm:entry-point')
  static Future<bool> _onIosBackground(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();
    return true;
  }
}
