import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gpstracking/data/api_service.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

/// Live map page for Kazoku mode - view tracked locations
class LiveMapPage extends StatefulWidget {
  const LiveMapPage({super.key});

  @override
  State<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends State<LiveMapPage> {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  List<CoordinateLog> _coordinates = [];
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  // Default center (can be updated based on user's location)
  LatLng _center = const LatLng(13.0827, 80.2707); // Chennai, India

  @override
  void initState() {
    super.initState();
    _loadCoordinates();

    // Refresh every 10 seconds
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _loadCoordinates(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _apiService.dispose();
    super.dispose();
  }

  Future<void> _loadCoordinates() async {
    final session = context.read<AppSession>();

    // For Kazoku mode, use selected child's ID; otherwise use own ID
    String? targetId;
    if (session.isKazoku && session.selectedChildId != null) {
      targetId = session.selectedChildId;
    } else {
      targetId = session.userId;
    }

    if (targetId == null) {
      setState(() {
        _loading = false;
        _error = 'No user selected';
      });
      return;
    }

    try {
      final coords = await _apiService.viewToday(targetId);
      if (mounted) {
        setState(() {
          _coordinates = coords;
          _loading = false;
          _error = null;

          // Center map on latest coordinate
          if (coords.isNotEmpty) {
            final latest = coords.last;
            _center = LatLng(latest.xCord, latest.yCord);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load coordinates';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = context.watch<AppSession>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: AppSpacing.paddingMd,
              child: Row(
                children: [
                  Text(
                    'Live Map',
                    style: context.textStyles.headlineMedium
                        ?.copyWith(color: scheme.onSurface),
                  ),
                  const Spacer(),
                  if (session.isKazoku && session.linkedChildren.isNotEmpty)
                    _ChildSelector(
                      children: session.linkedChildren,
                      selectedId: session.selectedChildId,
                      onChanged: (id) {
                        session.selectChild(id);
                        _loadCoordinates();
                      },
                    ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: scheme.primary),
                    onPressed: _loadCoordinates,
                  ),
                ],
              ),
            ),

            // Map
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError(context, scheme)
                      : _buildMap(context, scheme),
            ),

            // Info bar
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: scheme.surface,
                border: Border(
                  top: BorderSide(
                      color: scheme.outline.withValues(alpha: 0.16)),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded,
                      color: scheme.primary, size: 20),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _coordinates.isNotEmpty
                          ? '${_coordinates.length} points today • Last: ${_coordinates.last.loggedTime.split('T').last.split('.').first}'
                          : 'No location data today',
                      style: context.textStyles.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
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

  Widget _buildError(BuildContext context, ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded,
              size: 64, color: scheme.onSurfaceVariant),
          const SizedBox(height: AppSpacing.md),
          Text(
            _error ?? 'Unknown error',
            style: context.textStyles.bodyLarge
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          SubtleOutlineButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onPressed: _loadCoordinates,
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, ColorScheme scheme) {
    final points = _coordinates
        .map((c) => LatLng(c.xCord, c.yCord))
        .toList();

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
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
                    color: isLast ? scheme.primary : scheme.primary.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: isLast ? 3 : 1),
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
}

class _ChildSelector extends StatelessWidget {
  const _ChildSelector({
    required this.children,
    required this.selectedId,
    required this.onChanged,
  });

  final List<LinkedChild> children;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: DropdownButton<String>(
        value: selectedId,
        underline: const SizedBox.shrink(),
        items: children.map((child) {
          return DropdownMenuItem(
            value: child.odemoId,
            child: Text(child.displayName),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }
}
