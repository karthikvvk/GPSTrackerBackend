import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text('GPS Tracking', style: context.textStyles.headlineLarge?.copyWith(color: scheme.onSurface)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'UI-first build. Mock data only — ready to wire to localhost endpoints later.',
                style: context.textStyles.bodyLarge?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
              ),
              const SizedBox(height: AppSpacing.xl),
              Expanded(
                child: GradientCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(Icons.location_on_rounded, color: scheme.primary),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text('Track trips, devices, and activity', style: context.textStyles.titleLarge?.copyWith(color: scheme.onSurface)),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Map is intentionally represented as placeholders in this phase. We focus on flow + fields.',
                        style: context.textStyles.bodyMedium?.copyWith(color: scheme.onSurfaceVariant, height: 1.5),
                      ),
                      const Spacer(),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.sm,
                        children: [
                          PrimaryPillButton(
                            label: 'Sign in',
                            icon: Icons.login_rounded,
                            onPressed: () => context.push(AppRoutes.signIn),
                          ),
                          SubtleOutlineButton(
                            label: 'Create account',
                            icon: Icons.person_add_alt_1_rounded,
                            onPressed: () => context.push(AppRoutes.signUp),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Tip: When backend is ready, swap mock providers for real API/RoomDB adapters.',
                style: context.textStyles.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
