import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models.dart';

/// HTTP client for GPS Tracker backend
class ApiService {
  static const String baseUrl = 'http://10.134.74.182:5000';

  final http.Client _client;

  ApiService({http.Client? client}) : _client = client ?? http.Client();

  // =========================================================================
  // Server Status
  // =========================================================================

  /// Check if server is online
  Future<bool> checkServerStatus() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/serverstatus'))
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
      final body = jsonEncode({
        'userid': userId,
        'coords': coords.map((c) => c.toJson()).toList(),
      });

      final response = await _client
          .post(
            Uri.parse('$baseUrl/send'),
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
      final body = jsonEncode({
        'userid': userId,
        'last_synced_timestamp': lastSync.toUtc().toIso8601String(),
      });

      final response = await _client
          .post(
            Uri.parse('$baseUrl/sync'),
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
      final response = await _client
          .get(Uri.parse('$baseUrl/viewtoday?userid=$userId'))
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
      final response = await _client
          .get(Uri.parse('$baseUrl/sync_all?userid=$userId'))
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
      final response = await _client
          .get(Uri.parse('$baseUrl/history?userid=$userId'))
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
