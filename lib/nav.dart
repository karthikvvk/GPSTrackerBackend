import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gpstracking/pages/auth/role_select_page.dart';
import 'package:gpstracking/pages/auth/sign_in_page.dart';
import 'package:gpstracking/pages/auth/sign_up_page.dart';
import 'package:gpstracking/pages/dashboard/dashboard_page.dart';
import 'package:gpstracking/pages/map/live_map_page.dart';
import 'package:gpstracking/pages/profile/profile_page.dart';
import 'package:gpstracking/pages/profile/link_account_page.dart';
import 'package:gpstracking/pages/shell/app_shell.dart';
import 'package:gpstracking/pages/trips/trip_details_page.dart';
import 'package:gpstracking/pages/trips/trips_page.dart';
import 'package:gpstracking/pages/welcome_page.dart';
import 'package:gpstracking/state/app_session.dart';
import 'package:gpstracking/ui/app_motion.dart';

class AppRouter {
  static final AppSession session = AppSession();
  static final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>(debugLabel: 'root');

  static final GoRouter router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.welcome,
    refreshListenable: session,
    redirect: (context, state) {
      final signedIn = session.signedIn;
      final hasRole = session.hasRole;
      final loc = state.matchedLocation;

      // Auth routes
      final inAuth = loc == AppRoutes.welcome ||
          loc == AppRoutes.signIn ||
          loc == AppRoutes.signUp;

      // Role selection route
      final inRoleSelect = loc == AppRoutes.roleSelect;

      // Main app routes
      final inApp = loc.startsWith(AppRoutes.app);

      // Not signed in but trying to access app -> go to welcome
      if (!signedIn && (inApp || inRoleSelect)) {
        return AppRoutes.welcome;
      }

      // Signed in but no role yet -> go to role select
      if (signedIn && !hasRole && inApp) {
        return AppRoutes.roleSelect;
      }

      // Signed in with role but in auth flow -> go to dashboard
      if (signedIn && hasRole && inAuth) {
        return AppRoutes.dashboard;
      }

      // Signed in in auth flow but no role -> go to role select
      if (signedIn && !hasRole && inAuth && loc != AppRoutes.roleSelect) {
        return AppRoutes.roleSelect;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.welcome,
        name: 'welcome',
        pageBuilder: (context, state) =>
            _page(child: const WelcomePage(), state: state),
      ),
      GoRoute(
        path: AppRoutes.signIn,
        name: 'signIn',
        pageBuilder: (context, state) =>
            _page(child: const SignInPage(), state: state),
      ),
      GoRoute(
        path: AppRoutes.signUp,
        name: 'signUp',
        pageBuilder: (context, state) =>
            _page(child: const SignUpPage(), state: state),
      ),
      GoRoute(
        path: AppRoutes.roleSelect,
        name: 'roleSelect',
        pageBuilder: (context, state) =>
            _page(child: const RoleSelectPage(), state: state),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            name: 'dashboard',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const DashboardPage()),
          ),
          GoRoute(
            path: AppRoutes.trips,
            name: 'trips',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const TripsPage()),
            routes: [
              GoRoute(
                path: 'details/:tripId',
                name: 'tripDetails',
                pageBuilder: (context, state) {
                  final tripId = state.pathParameters['tripId'] ?? 'unknown';
                  return _page(
                      child: TripDetailsPage(tripId: tripId), state: state);
                },
              ),
            ],
          ),
          GoRoute(
            path: AppRoutes.liveMap,
            name: 'liveMap',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const LiveMapPage()),
          ),
          GoRoute(
            path: AppRoutes.profile,
            name: 'profile',
            pageBuilder: (context, state) =>
                NoTransitionPage(child: const ProfilePage()),
            routes: [
              GoRoute(
                path: 'link',
                name: 'linkAccount',
                parentNavigatorKey: _rootNavigatorKey,
                pageBuilder: (context, state) =>
                    _page(child: const LinkAccountPage(), state: state),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  static CustomTransitionPage<void> _page(
      {required Widget child, required GoRouterState state}) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      transitionDuration: AppMotion.page,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) =>
          AppMotion.fadeSlide(child, animation),
    );
  }
}

class AppRoutes {
  static const String welcome = '/welcome';
  static const String signIn = '/sign-in';
  static const String signUp = '/sign-up';
  static const String roleSelect = '/role-select';

  static const String app = '/app';
  static const String dashboard = '/app/dashboard';
  static const String trips = '/app/trips';
  static const String liveMap = '/app/map';
  static const String profile = '/app/profile';
  static const String linkAccount = '/app/profile/link';

  static String tripDetails(String tripId) =>
      '${AppRoutes.trips}/details/$tripId';
}
