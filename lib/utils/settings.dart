import 'dart:convert';
import 'package:flutter/services.dart';

/// Centralized settings loader — reads settings.json bundled as a Flutter asset.
/// This works correctly on both emulator and physical device.
class Settings {
  static Settings? _instance;
  static Map<String, dynamic>? _settings;

  Settings._();

  static Future<Settings> get instance async {
    if (_instance == null) {
      _instance = Settings._();
      await _instance!._loadSettings();
    }
    return _instance!;
  }

  Future<void> _loadSettings() async {
    try {
      final content = await rootBundle.loadString('settings.json');
      _settings = json.decode(content) as Map<String, dynamic>;
    } catch (e) {
      // settings.json not found or malformed — use defaults
      _settings = {};
    }
    print('searching_json');
    print(_settings);
  }

  // Update settings.json with your backend URL:
  //   Physical device on same WiFi → "http://192.168.0.101:5000"
  //   Emulator                     → "http://10.0.2.2:5000"
  //   Production (Render)          → "https://gpstrackerbackend-1.onrender.com"
  //
  // IMPORTANT: Do NOT include a trailing slash in settings.json.
  // The getter strips one defensively to avoid port-0 bugs in socket.io client.
  String get backendUrl {
    final raw = (_settings?['backend_url'] as String?) ?? 'http://localhost:5000';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }
  String get mongoUri => _settings?['mongo_uri'] ?? '';
  String get dbName => _settings?['db_name'] ?? 'GPSTracker';
  bool get debugMode => _settings?['debug_mode'] ?? false;
}
