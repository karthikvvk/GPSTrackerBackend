import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

class TripDetailsPage extends StatefulWidget {
  const TripDetailsPage({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailsPage> createState() => _TripDetailsPageState();
}

class _TripDetailsPageState extends State<TripDetailsPage> {
  DateTime selectedDate = DateTime.now();
  List<GpsPoint> gpsPoints = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadGpsData();
  }

  Future<void> _loadGpsData() async {
    setState(() => isLoading = true);
    
    // TODO: Fetch from MongoDB based on selectedDate and userid
    // For now, using mock data
    await Future.delayed(const Duration(milliseconds: 500));
    
    setState(() {
      gpsPoints = [
        GpsPoint(12.974417, 80.1867642, DateTime.parse('2026-01-26T00:36:46.017Z')),
        GpsPoint(12.975200, 80.187500, DateTime.parse('2026-01-26T00:38:46.017Z')),
        GpsPoint(12.976100, 80.188200, DateTime.parse('2026-01-26T00:40:46.017Z')),
        GpsPoint(12.977000, 80.189000, DateTime.parse('2026-01-26T00:42:46.017Z')),
      ];
      isLoading = false;
    });
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
        title: Text('Trip details', style: context.textStyles.titleLarge?.copyWith(color: scheme.onSurface)),
      ),
      body: SafeArea(
        child: ListView(
          padding: AppSpacing.paddingLg,
          children: [
            Text('Trip #${widget.tripId}', style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
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
                            Text('Selected Date', style: context.textStyles.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 2),
                            Text(
                              '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                              style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurface),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
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
                      Text('Route Map', style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurface)),
                      const Spacer(),
                      if (gpsPoints.isNotEmpty)
                        Text('${gpsPoints.length} points', style: context.textStyles.labelSmall?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Map Widget
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      color: scheme.surfaceContainerHighest,
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: isLoading
                          ? Center(child: CircularProgressIndicator(color: scheme.primary))
                          : gpsPoints.isEmpty
                              ? Center(
                                  child: Text(
                                    'No GPS data for this date',
                                    style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                                  ),
                                )
                              : TileMapWidget(points: gpsPoints),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Stats Row
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Distance', value: _calculateDistance(), icon: Icons.straighten_rounded)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _StatCard(label: 'Points', value: '${gpsPoints.length}', icon: Icons.location_on_rounded)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _StatCard(
                  label: 'Start', 
                  value: gpsPoints.isNotEmpty ? _formatTime(gpsPoints.first.timestamp) : '--:--', 
                  icon: Icons.play_arrow_rounded,
                )),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _StatCard(
                  label: 'End', 
                  value: gpsPoints.isNotEmpty ? _formatTime(gpsPoints.last.timestamp) : '--:--', 
                  icon: Icons.stop_rounded,
                )),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  String _calculateDistance() {
    if (gpsPoints.length < 2) return '0 km';
    
    double totalDistance = 0;
    for (int i = 0; i < gpsPoints.length - 1; i++) {
      totalDistance += _haversineDistance(
        gpsPoints[i].latitude,
        gpsPoints[i].longitude,
        gpsPoints[i + 1].latitude,
        gpsPoints[i + 1].longitude,
      );
    }
    
    return '${totalDistance.toStringAsFixed(2)} km';
  }
  
  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // Earth's radius in km
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }
  
  double _toRadians(double degree) => degree * math.pi / 180;
  
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class GpsPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  GpsPoint(this.latitude, this.longitude, this.timestamp);
}

// Map Widget with OSM Tile Support
class TileMapWidget extends StatefulWidget {
  final List<GpsPoint> points;

  const TileMapWidget({super.key, required this.points});

  @override
  State<TileMapWidget> createState() => _TileMapWidgetState();
}

class _TileMapWidgetState extends State<TileMapWidget> {
  late MapController mapController;
  final TileLoader tileLoader = TileLoader();

  @override
  void initState() {
    super.initState();
    mapController = MapController(widget.points);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    
    return GestureDetector(
      onScaleStart: (details) {
        mapController.onScaleStart(details);
      },
      onScaleUpdate: (details) {
        setState(() {
          mapController.onScaleUpdate(details);
        });
      },
      child: CustomPaint(
        painter: MapPainter(
          mapController: mapController,
          points: widget.points,
          primaryColor: scheme.primary,
          surfaceColor: scheme.surfaceContainerHighest,
          tileLoader: tileLoader,
        ),
        child: Container(),
      ),
    );
  }
}

class MapController {
  double zoom = 15.0;
  Offset offset = Offset.zero;
  Offset? _startFocalPoint;
  Offset? _startOffset;
  double? _startZoom;
  
  final List<GpsPoint> points;
  late LatLng center;

  MapController(this.points) {
    if (points.isNotEmpty) {
      // Calculate center from all points
      double avgLat = points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
      double avgLon = points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
      center = LatLng(avgLat, avgLon);
    } else {
      center = LatLng(0, 0);
    }
  }

  void onScaleStart(ScaleStartDetails details) {
    _startFocalPoint = details.focalPoint;
    _startOffset = offset;
    _startZoom = zoom;
  }

  void onScaleUpdate(ScaleUpdateDetails details) {
    // Handle zoom
    if (_startZoom != null) {
      zoom = (_startZoom! * details.scale).clamp(10.0, 18.0);
    }

    // Handle pan
    if (_startFocalPoint != null && _startOffset != null) {
      offset = _startOffset! + (details.focalPoint - _startFocalPoint!);
    }
  }

  // Convert lat/lng to tile coordinates
  TileCoord latLngToTile(LatLng latLng) {
    final n = math.pow(2, zoom);
    final x = ((latLng.longitude + 180) / 360 * n).floor();
    final latRad = latLng.latitude * math.pi / 180;
    final y = ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n).floor();
    return TileCoord(x, y, zoom.floor());
  }

  // Convert lat/lng to screen coordinates
  Offset latLngToScreen(LatLng latLng, Size size) {
    final scale = math.pow(2, zoom).toDouble();
    final worldSize = 256 * scale;

    // Mercator projection
    final x = (latLng.longitude + 180) / 360 * worldSize;
    final latRad = latLng.latitude * math.pi / 180;
    final y = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * worldSize;

    // Center point
    final centerX = (center.longitude + 180) / 360 * worldSize;
    final centerLatRad = center.latitude * math.pi / 180;
    final centerY = (1 - math.log(math.tan(centerLatRad) + 1 / math.cos(centerLatRad)) / math.pi) / 2 * worldSize;

    return Offset(
      size.width / 2 + (x - centerX) + offset.dx,
      size.height / 2 + (y - centerY) + offset.dy,
    );
  }

  // Convert tile coordinate to screen position
  Offset tileToScreen(TileCoord tile, Size size) {
    final scale = math.pow(2, zoom).toDouble();
    final worldSize = 256 * scale;
    final tileSize = 256.0;

    // Get center tile position
    final centerTile = latLngToTile(center);
    
    return Offset(
      size.width / 2 + (tile.x - centerTile.x) * tileSize + offset.dx,
      size.height / 2 + (tile.y - centerTile.y) * tileSize + offset.dy,
    );
  }
}

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}

class TileCoord {
  final int x;
  final int y;
  final int z;

  TileCoord(this.x, this.y, this.z);

  String get key => '$z/$x/$y';

  @override
  bool operator ==(Object other) =>
      other is TileCoord && x == other.x && y == other.y && z == other.z;

  @override
  int get hashCode => Object.hash(x, y, z);
}

// Tile Loader - Fetches OSM tiles
class TileLoader {
  final Map<String, ui.Image?> _cache = {};
  final Set<String> _loading = {};

  Future<ui.Image?> loadTile(TileCoord coord) async {
    final key = coord.key;
    
    // Return cached tile
    if (_cache.containsKey(key)) {
      return _cache[key];
    }

    // Prevent duplicate requests
    if (_loading.contains(key)) {
      return null;
    }

    _loading.add(key);

    try {
      // OSM tile URL: https://tile.openstreetmap.org/{z}/{x}/{y}.png
      final url = 'https://tile.openstreetmap.org/${coord.z}/${coord.x}/${coord.y}.png';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        _cache[key] = frame.image;
        return frame.image;
      }
    } catch (e) {
      // Tile loading failed, cache null to prevent retries
      _cache[key] = null;
    } finally {
      _loading.remove(key);
    }

    return null;
  }

  ui.Image? getCachedTile(TileCoord coord) {
    return _cache[coord.key];
  }
}

class MapPainter extends CustomPainter {
  final MapController mapController;
  final List<GpsPoint> points;
  final Color primaryColor;
  final Color surfaceColor;
  final TileLoader tileLoader;

  MapPainter({
    required this.mapController,
    required this.points,
    required this.primaryColor,
    required this.surfaceColor,
    required this.tileLoader,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Background
    final bgPaint = Paint()..color = surfaceColor;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Draw OSM tiles
    _drawTiles(canvas, size);

    if (points.isEmpty) return;

    // Draw route line
    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final point = mapController.latLngToScreen(
        LatLng(points[i].latitude, points[i].longitude),
        size,
      );

      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    // Draw start and end markers
    _drawMarker(canvas, mapController.latLngToScreen(
      LatLng(points.first.latitude, points.first.longitude), size,
    ), primaryColor, true);
    
    _drawMarker(canvas, mapController.latLngToScreen(
      LatLng(points.last.latitude, points.last.longitude), size,
    ), primaryColor, false);
  }

  void _drawTiles(Canvas canvas, Size size) {
    final zoom = mapController.zoom.floor();
    final centerTile = mapController.latLngToTile(mapController.center);
    
    // Calculate visible tile range
    final tilesX = (size.width / 256).ceil() + 2;
    final tilesY = (size.height / 256).ceil() + 2;
    
    final startX = centerTile.x - tilesX ~/ 2;
    final startY = centerTile.y - tilesY ~/ 2;
    
    for (int x = startX; x < startX + tilesX; x++) {
      for (int y = startY; y < startY + tilesY; y++) {
        final tileCoord = TileCoord(x, y, zoom);
        final position = mapController.tileToScreen(tileCoord, size);
        
        // Check if tile is visible
        if (position.dx + 256 < 0 || position.dx > size.width ||
            position.dy + 256 < 0 || position.dy > size.height) {
          continue;
        }

        // Try to get cached tile
        final tile = tileLoader.getCachedTile(tileCoord);
        
        if (tile != null) {
          // Draw the tile
          canvas.drawImage(
            tile,
            position,
            Paint(),
          );
        } else {
          // Load tile asynchronously
          tileLoader.loadTile(tileCoord).then((loadedTile) {
            if (loadedTile != null) {
              // Trigger repaint when tile loads
              // Note: In production, use a proper state management approach
            }
          });
          
          // Draw placeholder
          final placeholderPaint = Paint()..color = surfaceColor;
          canvas.drawRect(
            Rect.fromLTWH(position.dx, position.dy, 256, 256),
            placeholderPaint,
          );
        }
      }
    }
  }

  void _drawMarker(Canvas canvas, Offset position, Color color, bool isStart) {
    final markerPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(position, 8, borderPaint);
    canvas.drawCircle(position, 6, markerPaint);

    if (isStart) {
      final innerPaint = Paint()..color = Colors.white;
      canvas.drawCircle(position, 3, innerPaint);
    }
  }

  @override
  bool shouldRepaint(MapPainter oldDelegate) => true;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.icon});

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
                Text(label, style: context.textStyles.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}