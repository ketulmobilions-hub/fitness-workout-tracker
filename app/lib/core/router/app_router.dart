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
import '../../features/exercises/presentation/screens/create_exercise_screen.dart';
import '../../features/exercises/presentation/screens/exercise_detail_screen.dart';
import '../../features/exercises/presentation/screens/exercise_list_screen.dart';
import '../../features/active_session/active_session.dart';
import '../../features/progress/progress.dart';
import '../../features/streak/presentation/screens/streak_detail_screen.dart';
import '../../features/workout_history/workout_history.dart';
import '../../features/workout_plans/workout_plans.dart';
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
      GoRoute(
        path: AppRoutes.exercises,
        builder: (context, state) => const ExerciseListScreen(),
      ),
      // Static route must come BEFORE the parameterized sibling so GoRouter
      // does not match the literal string "create" as an exerciseId.
      GoRoute(
        path: AppRoutes.createExercise,
        builder: (context, state) => const CreateExerciseScreen(),
      ),
      GoRoute(
        path: AppRoutes.exerciseDetail,
        builder: (context, state) => ExerciseDetailScreen(
          exerciseId: state.pathParameters['exerciseId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.plans,
        builder: (context, state) => const PlanListScreen(),
      ),
      // Static route must come BEFORE the parameterized sibling so GoRouter
      // does not match the literal string "create" as a planId.
      GoRoute(
        path: AppRoutes.createPlan,
        builder: (context, state) => const PlanFormScreen(planId: null),
      ),
      GoRoute(
        path: AppRoutes.planDetail,
        builder: (context, state) => PlanDetailScreen(
          planId: state.pathParameters['planId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.editPlan,
        builder: (context, state) => PlanFormScreen(
          planId: state.pathParameters['planId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.activeWorkout,
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      GoRoute(
        path: AppRoutes.workoutSummary,
        builder: (context, state) {
          // Issue #10: guard against null extra on deep-link or process-death
          // navigation. This route is only reachable via in-app push (active
          // workout → summary), but a deep link or a back-stack restore with no
          // extra would previously throw a CastError and crash.
          final summary = state.extra;
          if (summary is! WorkoutSummary) {
            // Issue #6: include an AppBar so iOS users have a back affordance
            // when landing here via a deep link with no WorkoutSummary extra.
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Session data not available.')),
            );
          }
          return WorkoutSummaryScreen(summary: summary);
        },
      ),
      GoRoute(
        path: AppRoutes.workoutHistory,
        builder: (context, state) => const WorkoutHistoryScreen(),
      ),
      // GoRouter matches sibling routes by path specificity, not declaration
      // order. /history and /history/:sessionId are unambiguous as siblings —
      // no special ordering requirement here (unlike parent/child nesting).
      GoRoute(
        path: AppRoutes.sessionDetail,
        builder: (context, state) => SessionDetailScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.streak,
        builder: (context, state) => const StreakDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.progress,
        builder: (context, state) => const ProgressDashboardScreen(),
      ),
      // Static segment 'exercises' ensures this route is never ambiguous.
      GoRoute(
        path: AppRoutes.exerciseProgress,
        builder: (context, state) => ExerciseProgressScreen(
          exerciseId: state.pathParameters['exerciseId']!,
          // Issue #14: prefer query param (survives deep links / push
          // notifications), fall back to in-memory extra (in-app navigation),
          // then a generic label as last resort.
          exerciseName: state.uri.queryParameters['name'] ??
              (state.extra as String?) ??
              // Issue #3: 'Exercise Progress' is a legible fallback title for
              // deep-link navigation where neither the query param nor in-memory
              // extra is available (e.g. push notification with no name payload).
              // The screen replaces it with the authoritative name once loaded.
              'Exercise Progress',
        ),
      ),
    ],
  );
}
