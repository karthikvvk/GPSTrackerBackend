import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/data/local_db.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:gpstracking/utils/location_helper.dart';
import 'package:provider/provider.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  @override
  void initState() {
    super.initState();
    _initBackupCount();

    // Prompt location services only for child (tracking) users
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final session = context.read<AppSession>();
      if (session.isChild) {
        ensureLocationEnabled(context);
      }
    });
  }

  Future<void> _initBackupCount() async {
    final count = await LocalDb.getBackupCount();
    if (mounted) {
      context.read<AppSession>().setBackupCount(count);
    }
  }

  Future<void> _startTracking() async {
    await context.read<AppSession>().startTracking(context);
  }

  Future<void> _stopTracking() async {
    await context.read<AppSession>().stopTracking();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AppSession>();

    if (session.isChild) {
      return _buildChildDashboard(context, session);
    } else if (session.isParent) {
      return _buildParentDashboard(context, session);
    } else {
      return _buildDefaultDashboard(context, session);
    }
  }

  // ---------------------------------------------------------------------------
  // Child Dashboard
  // ---------------------------------------------------------------------------

  Widget _buildChildDashboard(BuildContext context, AppSession session) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Text(
            'Child Dashboard',
            style: context.textStyles.headlineLarge
                ?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your location is ${session.trackingActive ? "being shared" : "not being shared"}',
            style: context.textStyles.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          GradientCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: (session.trackingActive
                            ? scheme.tertiary
                            : scheme.outline)
                        .withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    session.trackingActive
                        ? Icons.wifi_tethering_rounded
                        : Icons.wifi_tethering_off_rounded,
                    color: session.trackingActive
                        ? scheme.tertiary
                        : scheme.outline,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.trackingActive
                            ? 'Tracking Active'
                            : 'Tracking Off',
                        style: context.textStyles.titleMedium
                            ?.copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        session.lastLocation != null
                            ? 'Last: (${session.lastLocation!.xCord.toStringAsFixed(4)}, '
                                '${session.lastLocation!.yCord.toStringAsFixed(4)})'
                            : 'No location recorded yet',
                        style: context.textStyles.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (session.backupCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${session.backupCount} offline',
                      style: context.textStyles.labelSmall
                          ?.copyWith(color: scheme.onErrorContainer),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: PrimaryPillButton(
                  label: session.trackingActive ? 'Stop' : 'Start',
                  icon: session.trackingActive
                      ? Icons.stop_rounded
                      : Icons.play_arrow_rounded,
                  onPressed:
                      session.trackingActive ? _stopTracking : _startTracking,
                ),
              ),
              if (session.trackingActive) ...[
                const SizedBox(width: AppSpacing.md),
                SubtleOutlineButton(
                  label: 'Restart',
                  icon: Icons.refresh_rounded,
                  onPressed: () async {
                    await _stopTracking();
                    await Future.delayed(const Duration(milliseconds: 300));
                    await _startTracking();
                  },
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (session.trackingLogs.isNotEmpty) ...[
            Text(
              'Activity Log',
              style: context.textStyles.titleMedium
                  ?.copyWith(color: scheme.onSurface),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              height: 200,
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border:
                    Border.all(color: scheme.outline.withValues(alpha: 0.16)),
              ),
              child: ListView.builder(
                reverse: true,
                itemCount: session.trackingLogs.length,
                itemBuilder: (context, index) {
                  final logs = session.trackingLogs;
                  final log = logs[logs.length - 1 - index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      log,
                      style: context.textStyles.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Parent Dashboard
  // ---------------------------------------------------------------------------

  Widget _buildParentDashboard(BuildContext context, AppSession session) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Text(
            'Parent Dashboard',
            style: context.textStyles.headlineLarge
                ?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'View locations of your family members',
            style: context.textStyles.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          GradientCard(
            onTap: () => context.go(AppRoutes.liveMap),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.map_rounded, color: scheme.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'View Live Map',
                        style: context.textStyles.titleMedium
                            ?.copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'See real-time locations on the map',
                        style: context.textStyles.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Family Members',
            style: context.textStyles.titleLarge
                ?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (session.linkedChildren.isEmpty)
            GradientCard(
              onTap: () => _showAddChildDialog(context),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.tertiary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child:
                        Icon(Icons.person_add_rounded, color: scheme.tertiary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Family Member',
                          style: context.textStyles.titleMedium
                              ?.copyWith(color: scheme.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Link a family member to track their location',
                          style: context.textStyles.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: scheme.onSurfaceVariant),
                ],
              ),
            )
          else
            ...session.linkedChildren.map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _LinkedChildCard(child: child),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddChildDialog(BuildContext context) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Family Member'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'User ID or Email',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                context.read<AppSession>().addLinkedChild(
                      LinkedChild(
                        odemoId: controller.text.trim(),
                        displayName: 'Family Member',
                        email: '${controller.text.trim()}@example.com',
                      ),
                    );
              }
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Default Dashboard
  // ---------------------------------------------------------------------------

  Widget _buildDefaultDashboard(BuildContext context, AppSession session) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Text(
            'Dashboard',
            style: context.textStyles.headlineLarge
                ?.copyWith(color: scheme.onSurface),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Viewing: ${session.subjectName}',
            style: context.textStyles.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.lg),
          GradientCard(
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.tertiary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.wifi_tethering_rounded,
                      color: scheme.tertiary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Live',
                        style: context.textStyles.titleMedium
                            ?.copyWith(color: scheme.onSurface),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Last update: just now',
                        style: context.textStyles.bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Linked child card
// -----------------------------------------------------------------------------

class _LinkedChildCard extends StatelessWidget {
  const _LinkedChildCard({required this.child});

  final LinkedChild child;

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
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary.withValues(alpha: 0.14),
            child: Icon(Icons.person_rounded, color: scheme.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  child.displayName,
                  style: context.textStyles.titleMedium
                      ?.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  child.lastLocation != null
                      ? 'Last seen: ${child.lastLocation!.loggedTime}'
                      : 'No location data yet',
                  style: context.textStyles.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          Icon(Icons.more_vert_rounded, color: scheme.onSurfaceVariant),
        ],
      ),
    );
  }
}
