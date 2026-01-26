import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/theme.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:math' as math;

class TripsPage extends StatefulWidget {
  const TripsPage({super.key});

  @override
  State<TripsPage> createState() => _TripsPageState();
}

class _TripsPageState extends State<TripsPage> {
  List<TripData> trips = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrips();
  }

  Future<void> _loadTrips() async {
    setState(() => isLoading = true);
    // TODO: Replace with your actual database path
    final db = await openDatabase('your_database.db');
    
    // Get list of date tables (your trip dates)
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    );
    
    List<TripData> loadedTrips = [];
    
    for (var table in tables) {
      final tableName = table['name'] as String;
      final coords = await db.query(
        tableName,
        columns: ['x_cord', 'y_cord', 'logged_time'],
        orderBy: 'logged_time ASC',
      );
      
      if (coords.isNotEmpty) {
        loadedTrips.add(TripData(
          id: tableName,
          tableName: tableName,
          coordinates: coords.map((c) => 
            LatLng(c['y_cord'] as double, c['x_cord'] as double)
          ).toList(),
          startTime: coords.first['logged_time'] as String,
          endTime: coords.last['logged_time'] as String,
        ));
      }
    }
    
    await db.close();
    
    setState(() {
      trips = loadedTrips;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: AppSpacing.paddingLg,
              children: [
                Text('History', style: context.textStyles.headlineLarge?.copyWith(color: scheme.onSurface)),
                const SizedBox(height: AppSpacing.sm),
                Text('Tap an item to view trip details.', style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.lg),
                ...trips.map((trip) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: _TripCard(
                    trip: trip,
                    onTap: () => context.push(AppRoutes.tripDetails(trip.id)),
                  ),
                )),
              ],
            ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip, required this.onTap});

  final TripData trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final distance = _calculateDistance(trip.coordinates);
    final duration = _calculateDuration(trip.startTime, trip.endTime);

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: AppSpacing.paddingMd,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(Icons.route_rounded, color: scheme.primary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(trip.tableName, style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurface)),
                        const SizedBox(height: 2),
                        Text('${trip.startTime} - ${trip.endTime}', style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                        const SizedBox(height: 2),
                        Text('${distance.toStringAsFixed(1)} km • $duration', style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  height: 180,
                  child: _TripMapPreview(coordinates: trip.coordinates),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _calculateDistance(List<LatLng> coords) {
    double totalDistance = 0;
    for (int i = 0; i < coords.length - 1; i++) {
      totalDistance += _haversineDistance(coords[i], coords[i + 1]);
    }
    return totalDistance;
  }

  double _haversineDistance(LatLng p1, LatLng p2) {
    const R = 6371; // Earth's radius in km
    final dLat = _toRadians(p2.lat - p1.lat);
    final dLon = _toRadians(p2.lng - p1.lng);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(p1.lat)) * math.cos(_toRadians(p2.lat)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _toRadians(double degrees) => degrees * math.pi / 180;

  String _calculateDuration(String start, String end) {
    // Simple duration calculation - adjust based on your time format
    return 'Duration';
  }
}

class _TripMapPreview extends StatelessWidget {
  const _TripMapPreview({required this.coordinates});

  final List<LatLng> coordinates;

  @override
  Widget build(BuildContext context) {
    if (coordinates.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('No route data')),
      );
    }

    final bounds = _calculateBounds(coordinates);
    final tiles = _calculateTilesWithPadding(bounds, zoom: 11, padding: 2);

    return Stack(
      children: [
        // OSM Tile Layer
        GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: tiles.width,
          ),
          itemCount: tiles.totalTiles,
          itemBuilder: (context, index) {
            final x = tiles.minX + (index % tiles.width);
            final y = tiles.minY + (index ~/ tiles.width);
            return Image.network(
              'https://tile.openstreetmap.org/${tiles.zoom}/$x/$y.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.grey[300]),
            );
          },
        ),
        // Route overlay
        CustomPaint(
          painter: _RoutePainter(
            coordinates: coordinates,
            bounds: bounds,
            tiles: tiles,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  MapBounds _calculateBounds(List<LatLng> coords) {
    double minLat = coords.first.lat;
    double maxLat = coords.first.lat;
    double minLng = coords.first.lng;
    double maxLng = coords.first.lng;

    for (var coord in coords) {
      minLat = math.min(minLat, coord.lat);
      maxLat = math.max(maxLat, coord.lat);
      minLng = math.min(minLng, coord.lng);
      maxLng = math.max(maxLng, coord.lng);
    }

    return MapBounds(minLat, maxLat, minLng, maxLng);
  }

  TileInfo _calculateTilesWithPadding(MapBounds bounds, {required int zoom, required int padding}) {
    final minTile = _latLngToTile(bounds.maxLat, bounds.minLng, zoom);
    final maxTile = _latLngToTile(bounds.minLat, bounds.maxLng, zoom);

    final minX = minTile.x - padding;
    final maxX = maxTile.x + padding;
    final minY = minTile.y - padding;
    final maxY = maxTile.y + padding;

    return TileInfo(
      minX: minX,
      maxX: maxX,
      minY: minY,
      maxY: maxY,
      width: maxX - minX + 1,
      height: maxY - minY + 1,
      zoom: zoom,
    );
  }

  TileCoordinate _latLngToTile(double lat, double lng, int zoom) {
    final n = math.pow(2, zoom);
    final x = ((lng + 180) / 360 * n).floor();
    final latRad = lat * math.pi / 180;
    final y = ((1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n).floor();
    return TileCoordinate(x, y);
  }
}

class _RoutePainter extends CustomPainter {
  final List<LatLng> coordinates;
  final MapBounds bounds;
  final TileInfo tiles;
  final Color color;

  _RoutePainter({
    required this.coordinates,
    required this.bounds,
    required this.tiles,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool first = true;

    for (var coord in coordinates) {
      final point = _latLngToPixel(coord, size);
      if (first) {
        path.moveTo(point.dx, point.dy);
        first = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }

    canvas.drawPath(path, paint);

    // Draw start/end markers
    if (coordinates.isNotEmpty) {
      final startPoint = _latLngToPixel(coordinates.first, size);
      final endPoint = _latLngToPixel(coordinates.last, size);

      final markerPaint = Paint()..color = color;
      canvas.drawCircle(startPoint, 6, markerPaint);
      canvas.drawCircle(endPoint, 6, Paint()..color = Colors.red);
    }
  }

  Offset _latLngToPixel(LatLng coord, Size size) {
    final tileSize = size.width / tiles.width;
    final n = math.pow(2, tiles.zoom);
    
    final x = (coord.lng + 180) / 360 * n;
    final latRad = coord.lat * math.pi / 180;
    final y = (1 - math.log(math.tan(latRad) + 1 / math.cos(latRad)) / math.pi) / 2 * n;

    final pixelX = (x - tiles.minX) * tileSize;
    final pixelY = (y - tiles.minY) * tileSize;

    return Offset(pixelX, pixelY);
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) => false;
}

// Data classes
class TripData {
  final String id;
  final String tableName;
  final List<LatLng> coordinates;
  final String startTime;
  final String endTime;

  TripData({
    required this.id,
    required this.tableName,
    required this.coordinates,
    required this.startTime,
    required this.endTime,
  });
}

class LatLng {
  final double lat;
  final double lng;
  LatLng(this.lat, this.lng);
}

class MapBounds {
  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  MapBounds(this.minLat, this.maxLat, this.minLng, this.maxLng);
}

class TileCoordinate {
  final int x;
  final int y;
  TileCoordinate(this.x, this.y);
}

class TileInfo {
  final int minX;
  final int maxX;
  final int minY;
  final int maxY;
  final int width;
  final int height;
  final int zoom;

  TileInfo({
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.width,
    required this.height,
    required this.zoom,
  });

  int get totalTiles => width * height;
}