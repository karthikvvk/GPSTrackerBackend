import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

/// Live map page for Parent mode - view tracked locations via relay
class LiveMapPage extends StatefulWidget {
  const LiveMapPage({super.key});

  @override
  State<LiveMapPage> createState() => _LiveMapPageState();
}

class _LiveMapPageState extends State<LiveMapPage> {
  final MapController _mapController = MapController();
  final List<CoordinateLog> _coordinates = [];
  bool _loading = true;
  String? _error;
  StreamSubscription? _locationSub;

  // Default center
  LatLng _center = const LatLng(13.0827, 80.2707); // Chennai, India

  @override
  void initState() {
    super.initState();
    _connectRelay();
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  void _connectRelay() {
    final session = context.read<AppSession>();

    // For Parent mode, use selected child's ID
    String? targetId;
    if (session.isParent && session.selectedChildId != null) {
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

    // Connect as parent and subscribe to child's live feed
    session.connectAsParent(targetId);

    // Listen for live locations from the relay
    final relay = session.relayService;
    if (relay != null) {
      _locationSub = relay.liveLocationStream.listen((coord) {
        if (mounted) {
          setState(() {
            _coordinates.add(coord);
            _loading = false;
            _error = null;
            _center = LatLng(coord.xCord, coord.yCord);
          });
        }
      });
    }

    setState(() {
      _loading = false;
    });
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
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Live Map',
                          style: context.textStyles.headlineMedium
                              ?.copyWith(color: scheme.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        // Child online indicator
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: session.childOnline
                                ? Colors.green
                                : scheme.outline,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          session.childOnline ? 'Online' : 'Offline',
                          style: context.textStyles.labelSmall?.copyWith(
                            color: session.childOnline
                                ? Colors.green
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (session.isParent && session.linkedChildren.isNotEmpty)
                    _ChildSelector(
                      children: session.linkedChildren,
                      selectedId: session.selectedChildId,
                      onChanged: (id) {
                        session.selectChild(id);
                        _coordinates.clear();
                        if (id != null) {
                          session.connectAsParent(id);
                        }
                      },
                    ),
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: scheme.primary),
                    onPressed: () {
                      setState(() {
                        _coordinates.clear();
                        _loading = true;
                      });
                      _connectRelay();
                    },
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
                  top:
                      BorderSide(color: scheme.outline.withValues(alpha: 0.16)),
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
                          ? '${_coordinates.length} points • Last: ${_coordinates.last.loggedTime.split('T').last.split('.').first}'
                          : session.childOnline
                              ? 'Waiting for location data...'
                              : 'Child device is offline',
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
            onPressed: _connectRelay,
          ),
        ],
      ),
    );
  }

  Widget _buildMap(BuildContext context, ColorScheme scheme) {
    final points = _coordinates.map((c) => LatLng(c.xCord, c.yCord)).toList();

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
