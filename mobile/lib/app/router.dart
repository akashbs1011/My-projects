import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../screens/disease_detail_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/register_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/results_screen.dart';
import '../screens/splash_screen.dart';
import '../utils/constants.dart';
import '../widgets/app_shell.dart';

/// Routing with a single authentication guard.
///
/// The guard lives here rather than in each screen, so there is exactly one
/// place that decides whether a person can see a page. [AuthProvider] is the
/// refresh listenable, so signing in or out re-evaluates every route at once.
class AppRouter {
  AppRouter(this._auth) {
    router = GoRouter(
      initialLocation: AppConstants.routeSplash,
      refreshListenable: _auth,
      redirect: _redirect,
      routes: _routes,
      errorBuilder: (context, state) => _NotFoundScreen(error: state.error),
    );
  }

  final AuthProvider _auth;
  late final GoRouter router;

  static const _publicRoutes = {
    AppConstants.routeLogin,
    AppConstants.routeRegister,
    AppConstants.routeForgotPassword,
    AppConstants.routeResetPassword,
  };

  String? _redirect(BuildContext context, GoRouterState state) {
    final location = state.matchedLocation;

    // Hold on the splash screen until the stored session has been checked, so
    // a returning person is never bounced to sign-in and back.
    if (_auth.status == AuthStatus.unknown) {
      return location == AppConstants.routeSplash ? null : AppConstants.routeSplash;
    }

    final isPublic = _publicRoutes.contains(location);
    final onSplash = location == AppConstants.routeSplash;

    if (!_auth.isAuthenticated) {
      return isPublic ? null : AppConstants.routeLogin;
    }

    // Signed in: keep them out of the auth screens and off the splash.
    if (isPublic || onSplash) return AppConstants.routeHome;
    return null;
  }

  final List<RouteBase> _routes = [
    GoRoute(
      path: AppConstants.routeSplash,
      builder: (_, __) => const SplashScreen(),
    ),
    GoRoute(
      path: AppConstants.routeLogin,
      builder: (_, __) => const LoginScreen(),
    ),
    GoRoute(
      path: AppConstants.routeRegister,
      builder: (_, __) => const RegisterScreen(),
    ),
    GoRoute(
      path: AppConstants.routeForgotPassword,
      builder: (_, __) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppConstants.routeResetPassword,
      builder: (_, state) =>
          ResetPasswordScreen(token: state.uri.queryParameters['token']),
    ),

    // Tabbed area. ShellRoute keeps the bottom navigation mounted so switching
    // tabs does not rebuild it or lose scroll position.
    ShellRoute(
      builder: (_, __, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: AppConstants.routeHome,
          builder: (_, __) => const HomeScreen(),
        ),
        GoRoute(
          path: AppConstants.routeHistory,
          builder: (_, __) => const HistoryScreen(),
        ),
        GoRoute(
          path: AppConstants.routeProfile,
          builder: (_, __) => const ProfileScreen(),
        ),
      ],
    ),

    // Full-screen pages pushed above the tabs.
    GoRoute(
      path: AppConstants.routeResults,
      builder: (_, __) => const ResultsScreen(),
    ),
    GoRoute(
      path: '${AppConstants.routeDisease}/:slug',
      builder: (_, state) => DiseaseDetailScreen(
        slug: state.pathParameters['slug']!,
        matchedSymptoms:
            (state.extra as List<String>?) ?? const <String>[],
      ),
    ),
  ];
}

class _NotFoundScreen extends StatelessWidget {
  const _NotFoundScreen({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.explore_off_outlined, size: 44),
              const SizedBox(height: 16),
              Text(
                "This page doesn't exist",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              const Text(
                'The link may be out of date. Head back and start a new analysis.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.go(AppConstants.routeHome),
                child: const Text('Go to symptoms'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
