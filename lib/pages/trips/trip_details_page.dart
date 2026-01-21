import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';

class TripDetailsPage extends StatelessWidget {
  const TripDetailsPage({super.key, required this.tripId});

  final String tripId;

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
            Text('Trip #$tripId', style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            GradientCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.map_rounded, color: scheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text('Map preview', style: context.textStyles.titleMedium?.copyWith(color: scheme.onSurface)),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Map rendering is intentionally omitted. Replace this with a map widget later.',
                    style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      color: scheme.primary.withValues(alpha: 0.08),
                      border: Border.all(color: scheme.outline.withValues(alpha: 0.18)),
                    ),
                    child: Center(
                      child: Text('MAP PLACEHOLDER', style: context.textStyles.labelLarge?.copyWith(color: scheme.primary)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Distance', value: '12.4 km', icon: Icons.straighten_rounded)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _StatCard(label: 'Avg speed', value: '42 kph', icon: Icons.speed_rounded)),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(child: _StatCard(label: 'Start', value: '08:41', icon: Icons.play_arrow_rounded)),
                const SizedBox(width: AppSpacing.md),
                Expanded(child: _StatCard(label: 'End', value: '09:04', icon: Icons.stop_rounded)),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Stops & notes', style: context.textStyles.titleLarge?.copyWith(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.sm),
            _NoteTile(title: 'Stop 1', subtitle: '5 min • Warehouse gate'),
            const SizedBox(height: AppSpacing.sm),
            _NoteTile(title: 'Note', subtitle: 'Traffic near bridge'),
          ],
        ),
      ),
    );
  }
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

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

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
          Icon(Icons.notes_rounded, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.textStyles.titleSmall?.copyWith(color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: context.textStyles.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
