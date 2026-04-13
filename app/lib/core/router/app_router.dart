import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/home_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/providers/auth_notifier.dart';
import '../../features/auth/providers/auth_state.dart';
import 'app_routes.dart';

part 'app_router.g.dart';

/// Pure redirect resolver — exported for unit testing.
///
/// Returns the target route path when a redirect is needed, or `null` to allow
/// the current navigation to proceed.
String? resolveAuthRedirect(AuthState authState, String location) {
  final onAuthPage =
      location.startsWith('/auth') || location == AppRoutes.splash;
  return switch (authState) {
    AuthInitializing() => null,
    AuthLoading() => null,
    AuthUnauthenticated() => onAuthPage ? null : AppRoutes.login,
    Authenticated() || AuthGuest() => onAuthPage ? AppRoutes.home : null,
  };
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // A ChangeNotifier that fires whenever the auth state changes.
  // GoRouter re-evaluates `redirect` on every notification.
  // Initialise to a safe sentinel; fireImmediately: true on the listener
  // below will synchronously update it to the actual current value before
  // the first redirect evaluation, eliminating the TOCTOU gap that would
  // exist between a ref.read snapshot and a subsequent ref.listen setup.
  final authListenable = ValueNotifier<AuthState>(
    const AuthState.initializing(),
  );
  ref.listen<AuthState>(
    authProvider,
    (_, next) => authListenable.value = next,
    fireImmediately: true,
  );
  ref.onDispose(authListenable.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: authListenable,
    redirect: (context, routerState) {
      // Read from authListenable.value — it is always in sync with
      // authProvider because ref.listen updates it before GoRouter fires
      // this redirect. This avoids going back through ref.read and makes
      // the coupling explicit.
      return resolveAuthRedirect(
        authListenable.value,
        routerState.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
}
