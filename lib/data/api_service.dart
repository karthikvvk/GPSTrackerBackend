import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';
import '../utils/settings.dart';

/// HTTP client for GPS Tracker backend
class ApiService {
  static String? _baseUrl;
  
  static Future<String> get baseUrl async {
    if (_baseUrl == null) {
      final settings = await Settings.instance;
      _baseUrl = settings.backendUrl;
    }
    return _baseUrl!;
  }

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // =========================================================================
  // Server Status
  // =========================================================================

  /// Check if server is online
  Future<bool> checkServerStatus() async {
    try {
      final url = await baseUrl;
      final response = await _client
          .get(Uri.parse('$url/serverstatus'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['server'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // Send Coordinates (Kodomo)
  // =========================================================================

  /// Send coordinates to server
  Future<bool> sendCoords(String userId, List<CoordinateLog> coords) async {
    try {
      final url = await baseUrl;
      final body = jsonEncode({
        'userid': userId,
        'coords': coords.map((c) => c.toJson()).toList(),
      });

      final response = await _client
          .post(
            Uri.parse('$url/send'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 10));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // =========================================================================
  // Sync & Fetch (Kazoku)
  // =========================================================================

  /// Resume sync from a specific timestamp
  Future<List<CoordinateLog>> syncFromTimestamp(
    String userId,
    DateTime lastSync,
  ) async {
    try {
      final url = await baseUrl;
      final body = jsonEncode({
        'userid': userId,
        'last_synced_timestamp': lastSync.toUtc().toIso8601String(),
      });

      final response = await _client
          .post(
            Uri.parse('$url/sync'),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final syncedData = data['synced_data'] as List<dynamic>;
        return syncedData
            .map((item) => CoordinateLog.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// View today's coordinates for a user
  Future<List<CoordinateLog>> viewToday(String userId) async {
    try {
      final url = await baseUrl;
      final response = await _client
          .get(Uri.parse('$url/viewtoday?userid=$userId'))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as List<dynamic>;
        return data
            .map((item) => CoordinateLog.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Sync all data for a user
  Future<List<CoordinateLog>> syncAll(String userId) async {
    try {
      final url = await baseUrl;
      final response = await _client
          .get(Uri.parse('$url/sync_all?userid=$userId'))
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final syncedData = data['synced_data'] as List<dynamic>;
        return syncedData
            .map((item) => CoordinateLog.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get available history dates for a user
  Future<List<String>> getHistory(String userId) async {
    try {
      final url = await baseUrl;
      final response = await _client
          .get(Uri.parse('$url/history?userid=$userId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final dates = data['available_dates'] as List<dynamic>;
        return dates.cast<String>();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Dispose the HTTP client
  void dispose() {
    _client.close();
  }
}
