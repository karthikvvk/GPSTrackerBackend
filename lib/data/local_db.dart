import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'models.dart';

/// SQLite database for offline-first location storage
class LocalDb {
  static Database? _database;
  static Completer<Database>? _initCompleter;
  static const String _dbName = 'gpstracker.db';
  static const int _dbVersion = 3;

  /// Table names
  static const String _logsTable = 'coordinate_logs';
  static const String _backupTable = 'backup_logs';

  /// Get database instance (singleton, safe against concurrent init)
  static Future<Database> get database async {
    if (_database != null) return _database!;

    // If another caller is already initialising, wait for it
    if (_initCompleter != null) return _initCompleter!.future;

    _initCompleter = Completer<Database>();
    try {
      _database = await _initDb();
      _initCompleter!.complete(_database!);
    } catch (e) {
      _initCompleter!.completeError(e);
      _initCompleter = null;
      rethrow;
    }
    return _database!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Main logs table (all synced logs)
    await db.execute('''
      CREATE TABLE $_logsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        x_cord REAL NOT NULL,
        y_cord REAL NOT NULL,
        logged_time TEXT NOT NULL UNIQUE,
        user_id TEXT,
        synced INTEGER DEFAULT 1,
        sim_date TEXT
      )
    ''');

    // Backup table (unsynced logs for offline mode)
    await db.execute('''
      CREATE TABLE $_backupTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        x_cord REAL NOT NULL,
        y_cord REAL NOT NULL,
        logged_time TEXT NOT NULL UNIQUE,
        user_id TEXT,
        sim_date TEXT
      )
    ''');

    // Index for faster date queries
    await db.execute('CREATE INDEX idx_logs_date ON $_logsTable(sim_date)');
    await db
        .execute('CREATE INDEX idx_backup_time ON $_backupTable(logged_time)');
  }

  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration: rename firebase_id to user_id
      await db.execute(
          'ALTER TABLE $_logsTable RENAME COLUMN firebase_id TO user_id');
      await db.execute(
          'ALTER TABLE $_backupTable RENAME COLUMN firebase_id TO user_id');
    }

    if (oldVersion < 3) {
      // Migration: Ensure sim_date column exists and populate it
      try {
        await db.execute('ALTER TABLE $_logsTable ADD COLUMN sim_date TEXT');
      } catch (_) {
        // Column might already exist, ignore error
      }

      try {
        await db.execute('ALTER TABLE $_backupTable ADD COLUMN sim_date TEXT');
      } catch (_) {
        // Column might already exist, ignore error
      }

      // Populate sim_date from logged_time if it's null or empty
      // logged_time format: YYYY-MM-DDTHH:MM:SS.mmmZ or similar
      // We extract YYYY-MM-DD
      await db.execute('''
        UPDATE $_logsTable 
        SET sim_date = substr(logged_time, 1, 10) 
        WHERE sim_date IS NULL OR sim_date = ''
      ''');

      await db.execute('''
        UPDATE $_backupTable 
        SET sim_date = substr(logged_time, 1, 10) 
        WHERE sim_date IS NULL OR sim_date = ''
      ''');
    }
  }

  // =========================================================================
  // Main Logs Table Operations
  // =========================================================================

  /// Insert a synced coordinate log
  static Future<void> insertLog(CoordinateLog log) async {
    final db = await database;
    final simDate = log.loggedTime.split('T').first;

    await db.insert(
      _logsTable,
      {
        ...log.toDb(),
        'sim_date': simDate,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all logs for a specific date
  static Future<List<CoordinateLog>> getLogsByDate(String date) async {
    final db = await database;
    final results = await db.query(
      _logsTable,
      where: 'sim_date = ?',
      whereArgs: [date],
      orderBy: 'logged_time ASC',
    );

    return results.map((row) => CoordinateLog.fromDb(row)).toList();
  }

  /// Get logs within a specific time range
  static Future<List<CoordinateLog>> getLogsByTimeRange(
      DateTime start, DateTime end) async {
    final db = await database;
    final startIso = start.toIso8601String();
    final endIso = end.toIso8601String();

    final results = await db.query(
      _logsTable,
      where: 'logged_time >= ? AND logged_time <= ?',
      whereArgs: [startIso, endIso],
      orderBy: 'logged_time ASC',
    );

    return results.map((row) => CoordinateLog.fromDb(row)).toList();
  }

  /// Get all unique dates with logs
  static Future<List<String>> getAllDates() async {
    final db = await database;
    final results = await db.rawQuery(
      'SELECT DISTINCT sim_date FROM $_logsTable ORDER BY sim_date DESC',
    );

    return results
        .map((row) => row['sim_date'] as String)
        .where((date) => date.isNotEmpty)
        .toList();
  }

  /// Get the latest logged_time stored for a given user_id.
  /// Returns null if no records exist for that user.
  /// Used by the parent to determine where incremental sync should start.
  static Future<String?> getLastTimestamp(String userId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT MAX(logged_time) as last_time FROM $_logsTable WHERE user_id = ?',
      [userId],
    );
    final value = result.first['last_time'];
    return value as String?;
  }

  /// Get all logs where logged_time > [fromTimestamp].
  /// If [cutoffTimestamp] is provided, also applies logged_time < [cutoffTimestamp].
  /// Pass an empty string for [fromTimestamp] to ignore the lower bound.
  static Future<List<CoordinateLog>> getLogsAfter(
    String fromTimestamp, [
    String? cutoffTimestamp,
  ]) async {
    final db = await database;
    List<Map<String, dynamic>> results;

    if (fromTimestamp.isEmpty && cutoffTimestamp == null) {
      results = await db.query(_logsTable, orderBy: 'logged_time ASC');
    } else if (fromTimestamp.isEmpty) {
      results = await db.query(
        _logsTable,
        where: 'logged_time < ?',
        whereArgs: [cutoffTimestamp],
        orderBy: 'logged_time ASC',
      );
    } else if (cutoffTimestamp == null) {
      results = await db.query(
        _logsTable,
        where: 'logged_time > ?',
        whereArgs: [fromTimestamp],
        orderBy: 'logged_time ASC',
      );
    } else {
      results = await db.query(
        _logsTable,
        where: 'logged_time > ? AND logged_time < ?',
        whereArgs: [fromTimestamp, cutoffTimestamp],
        orderBy: 'logged_time ASC',
      );
    }
    return results.map((row) => CoordinateLog.fromDb(row)).toList();
  }

  /// Get all logs
  static Future<List<CoordinateLog>> getAllLogs() async {
    final db = await database;
    final results = await db.query(_logsTable, orderBy: 'logged_time ASC');
    return results.map((row) => CoordinateLog.fromDb(row)).toList();
  }

  // =========================================================================
  // Backup Table Operations (for offline mode)
  // =========================================================================

  /// Insert a log into backup table (when offline)
  static Future<void> insertBackupLog(CoordinateLog log) async {
    final db = await database;
    final simDate = log.loggedTime.split('T').first;

    await db.insert(
      _backupTable,
      {
        'x_cord': log.xCord,
        'y_cord': log.yCord,
        'logged_time': log.loggedTime,
        'user_id': log.userId,
        'sim_date': simDate,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get all unsynced backup logs
  static Future<List<CoordinateLog>> getBackupLogs() async {
    final db = await database;
    final results = await db.query(
      _backupTable,
      orderBy: 'logged_time ASC',
    );

    return results.map((row) {
      return CoordinateLog(
        xCord: row['x_cord'] as double,
        yCord: row['y_cord'] as double,
        loggedTime: row['logged_time'] as String,
        userId: row['user_id'] as String?,
        synced: false,
      );
    }).toList();
  }

  /// Clear all backup logs (after successful sync)
  static Future<void> clearBackupLogs() async {
    final db = await database;
    await db.delete(_backupTable);
  }

  /// Delete specific backup log after syncing
  static Future<void> deleteBackupLog(String loggedTime) async {
    final db = await database;
    await db.delete(
      _backupTable,
      where: 'logged_time = ?',
      whereArgs: [loggedTime],
    );
  }

  /// Get count of backup logs
  static Future<int> getBackupCount() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM $_backupTable');
    return result.first['count'] as int;
  }

  // =========================================================================
  // Utility Methods
  // =========================================================================

  /// Close database
  static Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
      _initCompleter = null;
    }
  }

  /// Clear all data (for testing/logout)
  static Future<void> clearAll() async {
    final db = await database;
    await db.delete(_logsTable);
    await db.delete(_backupTable);
  }
}
