import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/theme.dart';

class TripsPage extends StatelessWidget {
  const TripsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Text('History', style: context.textStyles.headlineLarge?.copyWith(color: scheme.onSurface)),
          const SizedBox(height: AppSpacing.sm),
          Text('Tap an item to view trip details (map placeholder).', style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.lg),
          _TripCard(
            title: 'Office → Warehouse',
            time: '08:41 - 09:04',
            meta: '12.4 km • 42 kph avg',
            onTap: () => context.push(AppRoutes.tripDetails('t1')),
          ),
          const SizedBox(height: AppSpacing.md),
          _TripCard(
            title: 'Warehouse → Client',
            time: '10:12 - 10:29',
            meta: '8.1 km • 38 kph avg',
            onTap: () => context.push(AppRoutes.tripDetails('t2')),
          ),
          const SizedBox(height: AppSpacing.md),
          _TripCard(
            title: 'Client → Office',
            time: '12:06 - 12:35',
            meta: '15.6 km • 46 kph avg',
            onTap: () => context.push(AppRoutes.tripDetails('t3')),
          ),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.title, required this.time, required this.meta, required this.onTap});

  final String title;
  final String time;
  final String meta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

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
          child: Row(
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
                    Text(title, style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurface)),
                    const SizedBox(height: 2),
                    Text(time, style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text(meta, style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
