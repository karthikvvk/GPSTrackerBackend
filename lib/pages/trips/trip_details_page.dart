import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:gpstracking/data/local_db.dart';

class TripDetailsPage extends StatefulWidget {
  const TripDetailsPage({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  final MapController _mapController = MapController();

  DateTime selectedDate = DateTime.now();
  TimeOfDay startTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay endTime = const TimeOfDay(hour: 23, minute: 59);
  List<GpsPoint> gpsPoints = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGpsData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadGpsData() async {
    setState(() => isLoading = true);

    try {
      // Parse date from tripId if initial load
      if (widget.tripId != 'unknown' && gpsPoints.isEmpty) {
        try {
          selectedDate = DateTime.parse(widget.tripId);
        } catch (_) {
          // Keep default selectedDate
          selectedDate = DateTime.now();
        }
      }

      // Get date string for DB lookup (YYYY-MM-DD)
      final dateStr = selectedDate.toIso8601String().split('T').first;

      // Fetch all logs for the day (LocalDb uses sim_date column)
      final logs = await LocalDb.getLogsByDate(dateStr);

      // Create DateTime range for filtering
      final startDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        startTime.hour,
        startTime.minute,
      );

      final endDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        endTime.hour,
        endTime.minute,
      );

      if (mounted) {
        setState(() {
          gpsPoints = logs
              .map((log) => GpsPoint(
                    log.xCord, // Latitude (Fixed: xCord is Lat based on LiveMapPage)
                    log.yCord, // Longitude (Fixed: yCord is Lng based on LiveMapPage)
                    DateTime.parse(log.loggedTime),
                  ))
              .where((p) {
            // In-memory filter handles timezone interactions better than SQL string compare
            // We use isAfter/isBefore or strict comparison
            return (p.timestamp.isAfter(startDateTime) ||
                    p.timestamp.isAtSameMomentAs(startDateTime)) &&
                (p.timestamp.isBefore(endDateTime) ||
                    p.timestamp.isAtSameMomentAs(endDateTime));
          }).toList();
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

  Widget _buildMap(BuildContext context, ColorScheme scheme) {
    final points =
        gpsPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter:
            points.isNotEmpty ? points.first : const LatLng(13.0827, 80.2707),
        initialZoom: 15.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.kodomogps.tracker',
        ),

        // Path polyline
        if (points.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                strokeWidth: 3.0,
                color: scheme.primary.withValues(alpha: 0.7),
              ),
            ],
          ),

        // Markers
        MarkerLayer(
          markers: [
            // All points as small dots
            ...points.asMap().entries.map((entry) {
              final isLast = entry.key == points.length - 1;
              return Marker(
                point: entry.value,
                width: isLast ? 30 : 12,
                height: isLast ? 30 : 12,
                child: Container(
                  decoration: BoxDecoration(
                    color: isLast
                        ? scheme.primary
                        : scheme.primary.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: Colors.white, width: isLast ? 3 : 1),
                    boxShadow: isLast
                        ? [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ]
                        : null,
                  ),
                  child: isLast
                      ? Icon(Icons.person_pin_circle_rounded,
                          color: Colors.white, size: 18)
                      : null,
                ),
              );
            }),
          ],
        ),
      ],
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

                  // Map Widget using LiveMapPage style
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
                              : _buildMap(context, scheme),
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
