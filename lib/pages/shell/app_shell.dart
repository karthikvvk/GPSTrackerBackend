import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/nav.dart';
import 'package:gpstracking/theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith(AppRoutes.trips)) return 1;
    if (location.startsWith(AppRoutes.profile)) return 2;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppRoutes.dashboard);
        return;
      case 1:
        context.go(AppRoutes.trips);
        return;
      case 2:
        context.go(AppRoutes.profile);
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final location = GoRouterState.of(context).uri.toString();
    final index = _indexForLocation(location);

    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(key: ValueKey(location), child: child),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: scheme.outline.withValues(alpha: 0.16)),
          ),
          child: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (i) => _onTap(context, i),
            backgroundColor: Colors.transparent,
            elevation: 0,
            indicatorColor: scheme.primary.withValues(alpha: 0.12),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined, color: scheme.onSurfaceVariant),
                selectedIcon: Icon(Icons.dashboard_rounded, color: scheme.primary),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.route_outlined, color: scheme.onSurfaceVariant),
                selectedIcon: Icon(Icons.route_rounded, color: scheme.primary),
                label: 'History',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded, color: scheme.onSurfaceVariant),
                selectedIcon: Icon(Icons.person_rounded, color: scheme.primary),
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
