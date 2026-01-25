import 'dart:convert';
import 'dart:io';

/// Centralized settings loader for the application
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
      // Try to find settings.json relative to the executable
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final possiblePaths = [
        'settings.json',
        '$exeDir/settings.json',
        '$exeDir/../settings.json',
        '$exeDir/data/settings.json',
      ];

      for (final path in possiblePaths) {
        final file = File(path);
        if (await file.exists()) {
          final content = await file.readAsString();
          _settings = json.decode(content);
          return;
        }
      }
      // Fallback to defaults
      _settings = {};
    } catch (e) {
      _settings = {};
    }
  }

  String get backendUrl => _settings?['backend_url'] ?? 'http://localhost:5000';
  String get mongoUri => _settings?['mongo_uri'] ?? '';
  String get dbName => _settings?['db_name'] ?? 'GPSTracker';
  bool get debugMode => _settings?['debug_mode'] ?? false;
}
