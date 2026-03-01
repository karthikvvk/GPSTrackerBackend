import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/data/models.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:provider/provider.dart';

/// Role selection page - choose between Kodomo (being tracked) or Kazoku (tracking)
class RoleSelectPage extends StatelessWidget {
  const RoleSelectPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = context.watch<AppSession>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Welcome, ${session.displayName ?? 'User'}!',
                style: context.textStyles.headlineLarge
                    ?.copyWith(color: scheme.onSurface),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'How will you use this app?',
                style: context.textStyles.bodyLarge
                    ?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Kodomo option
              GradientCard(
                onTap: () {
                  session.setRole(UserRole.kodomo);
                  context.go(AppRoutes.dashboard);
                },
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(Icons.location_on_rounded,
                          size: 28, color: scheme.primary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "I'm being tracked",
                            style: context.textStyles.titleLarge
                                ?.copyWith(color: scheme.onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Share your location with family members (Kodomo mode)',
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

              const SizedBox(height: AppSpacing.md),

              // Kazoku option
              GradientCard(
                onTap: () {
                  session.setRole(UserRole.kazoku);
                  context.go(AppRoutes.dashboard);
                },
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: scheme.tertiary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(Icons.visibility_rounded,
                          size: 28, color: scheme.tertiary),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "I'm tracking someone",
                            style: context.textStyles.titleLarge
                                ?.copyWith(color: scheme.onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'View locations of linked family members (Kazoku mode)',
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

              const Spacer(),

              // Sign out option
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    await session.signOut();
                    if (context.mounted) {
                      context.go(AppRoutes.welcome);
                    }
                  },
                  icon: Icon(Icons.logout_rounded, color: scheme.onSurfaceVariant),
                  label: Text(
                    'Sign out',
                    style: context.textStyles.labelLarge
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
