import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
          // QR Code section for Child (child) users
          if (session.isChild) ...[
            Text('Your QR Code',
                style: context.textStyles.titleLarge
                    ?.copyWith(color: scheme.onSurface)),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: AppSpacing.paddingLg,
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border:
                    Border.all(color: scheme.outline.withValues(alpha: 0.16)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: QrImageView(
                      data:
                          '${session.email ?? ''}:kodomo_link_${session.userId ?? ''}',
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_rounded,
                          size: 20, color: scheme.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Scan QR',
                        style: context.textStyles.titleSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          decorationColor: scheme.primary,
                          decorationThickness: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Show this QR code to your parent/guardian.\nThey can scan it to link your account.',
                    style: context.textStyles.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (!session.isChild) ...[
            Text('Linked children',
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
                  // --- Per-child list ---
                  if (session.linkedChildren.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          Icon(Icons.person_search_rounded,
                              size: 20, color: scheme.onSurfaceVariant),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            'No children linked yet',
                            style: context.textStyles.bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  else
                    ...session.linkedChildren.map((child) => Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color:
                                      scheme.primary.withValues(alpha: 0.10),
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                                child: Icon(Icons.person_rounded,
                                    size: 18, color: scheme.primary),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      child.displayName,
                                      style: context.textStyles.titleSmall
                                          ?.copyWith(
                                              color: scheme.onSurface),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      child.email,
                                      style: context.textStyles.bodySmall
                                          ?.copyWith(
                                              color: scheme.onSurfaceVariant),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.link_off_rounded,
                                    size: 20, color: scheme.error),
                                tooltip: 'Unlink',
                                onPressed: () => context
                                    .read<AppSession>()
                                    .unlinkChildById(child.odemoId),
                              ),
                            ],
                          ),
                        )),
                  const Divider(height: AppSpacing.md),
                  // --- Always-active Link Account button ---
                  SubtleOutlineButton(
                    label: 'Link Account',
                    icon: Icons.person_add_alt_1_rounded,
                    onPressed: () => context.go(AppRoutes.linkAccount),
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
}
