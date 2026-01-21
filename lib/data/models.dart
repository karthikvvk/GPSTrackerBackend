/// Data models for GPS Tracker application

/// User role determining app behavior
enum UserRole {
  /// Child being tracked (Kodomo)
  kodomo,

  /// Parent viewing tracked child (Kazoku)
  kazoku,
}

/// Coordinate log entry
class CoordinateLog {
  final double xCord;
  final double yCord;
  final String loggedTime;
  final String? userId;
  final bool synced;

  const CoordinateLog({
    required this.xCord,
    required this.yCord,
    required this.loggedTime,
    this.userId,
    this.synced = false,
  });

  /// Create from JSON (API response)
  factory CoordinateLog.fromJson(Map<String, dynamic> json) {
    return CoordinateLog(
      xCord: (json['x_cord'] as num).toDouble(),
      yCord: (json['y_cord'] as num).toDouble(),
      loggedTime: json['logged_time'] as String,
      userId: json['userid'] as String?,
      synced: true,
    );
  }

  /// Convert to JSON for API request
  Map<String, dynamic> toJson() {
    return {
      'x_cord': xCord,
      'y_cord': yCord,
      'logged_time': loggedTime,
      if (userId != null) 'userid': userId,
    };
  }

  /// Create from database row
  factory CoordinateLog.fromDb(Map<String, dynamic> row) {
    return CoordinateLog(
      xCord: row['x_cord'] as double,
      yCord: row['y_cord'] as double,
      loggedTime: row['logged_time'] as String,
      userId: row['user_id'] as String?,
      synced: row['synced'] == 1,
    );
  }

  /// Convert to database row
  Map<String, dynamic> toDb() {
    return {
      'x_cord': xCord,
      'y_cord': yCord,
      'logged_time': loggedTime,
      'user_id': userId,
      'synced': synced ? 1 : 0,
    };
  }

  @override
  String toString() =>
      'CoordinateLog(x: $xCord, y: $yCord, time: $loggedTime, synced: $synced)';
}

/// Linked child account (for Kazoku mode)
class LinkedChild {
  final String odemoId;
  final String displayName;
  final String email;
  final DateTime? lastSeen;
  final CoordinateLog? lastLocation;

  const LinkedChild({
    required this.odemoId,
    required this.displayName,
    required this.email,
    this.lastSeen,
    this.lastLocation,
  });

  LinkedChild copyWith({
    String? odemoId,
    String? displayName,
    String? email,
    DateTime? lastSeen,
    CoordinateLog? lastLocation,
  }) {
    return LinkedChild(
      odemoId: odemoId ?? this.odemoId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      lastSeen: lastSeen ?? this.lastSeen,
      lastLocation: lastLocation ?? this.lastLocation,
    );
  }
}
