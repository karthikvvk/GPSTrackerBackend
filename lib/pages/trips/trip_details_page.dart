import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class TripDetailsPage extends StatefulWidget {
  const TripDetailsPage({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 23, minute: 59);
  List<GpsPoint> gpsPoints = [];
  bool isLoading = false;
  Database? _database;

  @override
  void initState() {
    super.initState();
    _initDb();
  }

  Future<void> _initDb() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'gpstracker.db');

      _database = await openDatabase(path);
      _loadGpsData();
    } catch (e) {
      debugPrint('Error opening database: $e');
    }
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }

  Future<void> _loadGpsData() async {
    if (_database == null) return;

    setState(() => isLoading = true);

    try {
      // Parse date from tripId if initial load
      String dateStr;
      if (widget.tripId != 'unknown' && gpsPoints.isEmpty) {
        dateStr = widget.tripId;
        try {
          selectedDate = DateTime.parse(dateStr);
        } catch (_) {
          dateStr = selectedDate.toIso8601String().split('T').first;
        }
      } else {
        dateStr = selectedDate.toIso8601String().split('T').first;
      }

      // Convert to table name format: 2026_01_26
      String tableName = dateStr.replaceAll('-', '_');

      // Create DateTime range for query
      DateTime startDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        startTime.hour,
        startTime.minute,
      );

      DateTime endDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        endTime.hour,
        endTime.minute,
      );

      // Check if table exists
      final tableExists = await _database!.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name=?",
          [tableName]);

      if (tableExists.isEmpty) {
        if (mounted) {
          setState(() {
            gpsPoints = [];
            isLoading = false;
          });
        }
        return;
      }

      // Query SQLite with time range filter
      // Structure: _id, userid, x_cord, y_cord, logged_time
      final results = await _database!.rawQuery('''
        SELECT * FROM `$tableName`
        WHERE logged_time >= ? AND logged_time <= ?
        ORDER BY logged_time ASC
        ''', [startDateTime.toIso8601String(), endDateTime.toIso8601String()]);

      if (mounted) {
        setState(() {
          gpsPoints = results
              .map((row) => GpsPoint(
                    (row['y_cord'] as num).toDouble(), // Latitude
                    (row['x_cord'] as num).toDouble(), // Longitude
                    DateTime.parse(row['logged_time'] as String),
                  ))
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading GPS data: $e');
      if (mounted) {
        setState(() {
          gpsPoints = [];
          isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
      _loadGpsData();
    }
  }

  Future<void> _selectTimeRange(BuildContext context) async {
    final scheme = Theme.of(context).colorScheme;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Time Range'),
        content: StatefulBuilder(
          builder: (context, setDialogState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Start Time
              ListTile(
                leading: Icon(Icons.access_time, color: scheme.primary),
                title: const Text('Start Time'),
                trailing: Text(
                  startTime.format(context),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: startTime,
                  );
                  if (picked != null) {
                    setDialogState(() => startTime = picked);
                  }
                },
              ),
              const Divider(),
              // End Time
              ListTile(
                leading: Icon(Icons.access_time_filled, color: scheme.primary),
                title: const Text('End Time'),
                trailing: Text(
                  endTime.format(context),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: endTime,
                  );
                  if (picked != null) {
                    setDialogState(() => endTime = picked);
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {});
              _loadGpsData();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: Icon(Icons.arrow_back_rounded, color: scheme.onSurface),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
        ),
        title: Text('Trip details',
            style: context.textStyles.titleLarge
                ?.copyWith(color: scheme.onSurface)),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.paddingLg,
          children: [
            Text('Trip #${widget.tripId}',
                style: context.textStyles.titleMedium
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),

            // Date Selection Card
            GradientCard(
              child: InkWell(
                onTap: () => _selectDate(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: scheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Selected Date',
                                style: context.textStyles.labelMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: context.textStyles.titleMedium
                                  ?.copyWith(color: scheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Time Range Selection Card
            GradientCard(
              child: InkWell(
                onTap: () => _selectTimeRange(context),
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Padding(
                  padding: AppSpacing.paddingMd,
                  child: Row(
                    children: [
                      Icon(Icons.schedule_rounded, color: scheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Time Range',
                                style: context.textStyles.labelMedium
                                    ?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(
                              '${startTime.format(context)} - ${endTime.format(context)}',
                              style: context.textStyles.titleMedium
                                  ?.copyWith(color: scheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded,
                          color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            // Map Card
            GradientCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map_rounded, color: scheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Route Map',
                          style: context.textStyles.titleMedium
                              ?.copyWith(color: scheme.onSurface)),
                      const Spacer(),
                      if (gpsPoints.isNotEmpty)
                        Text('${gpsPoints.length} points',
                            style: context.textStyles.labelSmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Map Widget with OpenStreetMap
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      color: scheme.surfaceContainerHighest,
                      border: Border.all(
                          color: scheme.outline.withValues(alpha: 0.18)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: isLoading
                          ? Center(
                              child: CircularProgressIndicator(
                                  color: scheme.primary))
                          : gpsPoints.isEmpty
                              ? Center(
                                  child: Text(
                                    'No GPS data for this time range',
                                    style: context.textStyles.bodyMedium
                                        ?.copyWith(
                                            color: scheme.onSurfaceVariant),
                                  ),
                                )
                              : FlutterMap(
                                  options: MapOptions(
                                    initialCameraFit: CameraFit.bounds(
                                      bounds: LatLngBounds.fromPoints(
                                        gpsPoints
                                            .map((p) =>
                                                LatLng(p.latitude, p.longitude))
                                            .toList(),
                                      ),
                                      padding: const EdgeInsets.all(20),
                                    ),
                                    interactionOptions:
                                        const InteractionOptions(
                                      flags: InteractiveFlag.all &
                                          ~InteractiveFlag.rotate,
                                    ),
                                  ),
                                  children: [
                                    // OpenStreetMap Tile Layer
                                    TileLayer(
                                      urlTemplate:
                                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                      userAgentPackageName:
                                          'com.kodomogps.tracker',
                                      maxZoom: 19,
                                      minZoom: 1,
                                    ),
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: gpsPoints
                                              .map((p) => LatLng(
                                                  p.latitude, p.longitude))
                                              .toList(),
                                          strokeWidth: 4.0,
                                          color: scheme.primary,
                                        ),
                                      ],
                                    ),
                                    MarkerLayer(
                                      markers: [
                                        // Start Marker (White with border)
                                        if (gpsPoints.isNotEmpty)
                                          Marker(
                                            point: LatLng(
                                                gpsPoints.first.latitude,
                                                gpsPoints.first.longitude),
                                            width: 12,
                                            height: 12,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: scheme.primary,
                                                    width: 3),
                                              ),
                                            ),
                                          ),
                                        // End Marker (Filled with shadow)
                                        if (gpsPoints.isNotEmpty)
                                          Marker(
                                            point: LatLng(
                                                gpsPoints.last.latitude,
                                                gpsPoints.last.longitude),
                                            width: 16,
                                            height: 16,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: scheme.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                    color: Colors.white,
                                                    width: 2),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: scheme.primary
                                                        .withValues(alpha: 0.4),
                                                    blurRadius: 8,
                                                    spreadRadius: 2,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GpsPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  GpsPoint(this.latitude, this.longitude, this.timestamp);
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: scheme.primary, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: context.textStyles.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value,
                    style: context.textStyles.titleMedium
                        ?.copyWith(color: scheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
