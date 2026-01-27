import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/theme.dart';
import 'package:gpstracking/ui/app_widgets.dart';
import 'package:provider/provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final session = context.watch<AppSession>();
    final subjectName = session.subjectName;

    return SafeArea(
      child: ListView(
        padding: AppSpacing.paddingLg,
        children: [
          Text('Profile',
              style: context.textStyles.headlineLarge
                  ?.copyWith(color: scheme.onSurface)),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: scheme.primary.withValues(alpha: 0.14),
                  child: Icon(Icons.person_rounded, color: scheme.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(session.displayName ?? 'User',
                          style: context.textStyles.titleMedium
                              ?.copyWith(color: scheme.onSurface)),
                      const SizedBox(height: 2),
                      if (session.email != null)
                        Text(session.email!,
                            style: context.textStyles.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (!session.isKodomo) ...[
            Text('Linked account',
                style: context.textStyles.titleLarge
                    ?.copyWith(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: AppSpacing.paddingMd,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border:
                    Border.all(color: scheme.outline.withValues(alpha: 0.16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: scheme.primary.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(Icons.link_rounded, color: scheme.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.hasLinkedChild
                                  ? 'Viewing ${session.linkedChildName}'
                                  : 'Viewing You',
                              style: context.textStyles.titleMedium
                                  ?.copyWith(color: scheme.onSurface),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Dashboard uses this account for live and history.',
                              style: context.textStyles.bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.sm,
                    children: [
                      SubtleOutlineButton(
                        label: 'Link Account',
                        icon: Icons.person_add_alt_1_rounded,
                        onPressed: session.hasLinkedChild
                            ? null
                            : () => _showLinkAccountDialog(context),
                      ),
                      SubtleOutlineButton(
                        label: 'Unlink',
                        icon: Icons.link_off_rounded,
                        onPressed: session.hasLinkedChild
                            ? () => context.read<AppSession>().unlinkChild()
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Currently showing: $subjectName',
                    style: context.textStyles.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text('Settings',
              style: context.textStyles.titleLarge
                  ?.copyWith(color: scheme.onSurface)),
          const SizedBox(height: AppSpacing.sm),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: AppSpacing.paddingMd,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.dark_mode_rounded, color: scheme.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                    child: Text('Dark Mode',
                        style: context.textStyles.titleMedium
                            ?.copyWith(color: scheme.onSurface))),
                Switch(
                  value: session.themeMode == ThemeMode.dark,
                  onChanged: (_) => context.read<AppSession>().toggleTheme(),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          OutlinedButton.icon(
            onPressed: () {
              context.read<AppSession>().signOut();
              context.go(AppRoutes.welcome);
            },
            icon: Icon(Icons.logout_rounded, color: scheme.onSurface),
            label: Text('Sign out',
                style: context.textStyles.labelLarge
                    ?.copyWith(color: scheme.onSurface)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              splashFactory: NoSplash.splashFactory,
            ),
          ),
        ],
      ),
    );
  }

  void _showLinkAccountDialog(BuildContext context) {
    final accountController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Link Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: accountController,
              decoration: const InputDecoration(
                labelText: 'Account ID / Email',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (accountController.text.trim().isNotEmpty) {
                // In a real app, verify credentials here
                context
                    .read<AppSession>()
                    .linkChild(childName: accountController.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Link'),
          ),
        ],
      ),
    );
  }
}
