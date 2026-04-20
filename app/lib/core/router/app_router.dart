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
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/settings_screen.dart';
import '../../features/progress/progress.dart';
import '../../features/streak/presentation/screens/streak_detail_screen.dart';
import '../../features/workout_history/workout_history.dart';
import '../../features/workout_plans/workout_plans.dart';
import '../navigation/app_shell.dart';
import 'app_routes.dart';

part 'app_router.g.dart';

// ── Navigator keys ────────────────────────────────────────────────────────────
// Defined at module level so they are created once and stable for the app's
// lifetime. The root key is passed to GoRouter so that full-screen routes
// declared with parentNavigatorKey: _rootKey always render above the shell.

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _branch0Key = GlobalKey<NavigatorState>(debugLabel: 'branch-home');
final _branch1Key = GlobalKey<NavigatorState>(debugLabel: 'branch-plans');
final _branch2Key = GlobalKey<NavigatorState>(debugLabel: 'branch-progress');
final _branch3Key = GlobalKey<NavigatorState>(debugLabel: 'branch-profile');

final _branchKeys = [_branch0Key, _branch1Key, _branch2Key, _branch3Key];

// ── Auth redirect ─────────────────────────────────────────────────────────────

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

// ── Router provider ───────────────────────────────────────────────────────────

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
    navigatorKey: _rootKey,
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
      // ── Pre-auth / unauthenticated ───────────────────────────────────────
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

      // ── Authenticated shell — bottom nav always visible ──────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => AppShell(
          navigationShell: navigationShell,
          branchNavigatorKeys: _branchKeys,
        ),
        branches: [
          // Branch 0: Home / Dashboard (nav item 0)
          StatefulShellBranch(
            navigatorKey: _branch0Key,
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),

          // Branch 1: Plans (nav item 1)
          StatefulShellBranch(
            navigatorKey: _branch1Key,
            routes: [
              GoRoute(
                path: AppRoutes.plans,
                builder: (context, state) => const PlanListScreen(),
              ),
            ],
          ),

          // Branch 2: Progress (nav item 3 — nav item 2 is the Log action)
          StatefulShellBranch(
            navigatorKey: _branch2Key,
            routes: [
              GoRoute(
                path: AppRoutes.progress,
                builder: (context, state) => const ProgressDashboardScreen(),
              ),
            ],
          ),

          // Branch 3: Profile (nav item 4)
          StatefulShellBranch(
            navigatorKey: _branch3Key,
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── Full-screen routes (push over shell — no bottom nav) ─────────────
      // All routes below use parentNavigatorKey: _rootKey so GoRouter always
      // places them on the root navigator, above the shell scaffold.

      // Exercises
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.exercises,
        builder: (context, state) => const ExerciseListScreen(),
      ),
      // Static route must come BEFORE the parameterized sibling so GoRouter
      // does not match the literal string "create" as an exerciseId.
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.createExercise,
        builder: (context, state) => const CreateExerciseScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.exerciseDetail,
        builder: (context, state) => ExerciseDetailScreen(
          exerciseId: state.pathParameters['exerciseId']!,
        ),
      ),

      // Workout plans (detail / create / edit — full-screen, no bottom nav)
      // Static route must come BEFORE the parameterized sibling so GoRouter
      // does not match the literal string "create" as a planId.
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.createPlan,
        builder: (context, state) => const PlanFormScreen(planId: null),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.planDetail,
        builder: (context, state) => PlanDetailScreen(
          planId: state.pathParameters['planId']!,
        ),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.editPlan,
        builder: (context, state) => PlanFormScreen(
          planId: state.pathParameters['planId']!,
        ),
      ),

      // Active workout (full-screen — launched from the Log action tab)
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.activeWorkout,
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
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

      // Workout history
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.workoutHistory,
        builder: (context, state) => const WorkoutHistoryScreen(),
      ),
      // GoRouter evaluates sibling routes in declaration order. These two paths
      // are unambiguous — /history can never match /history/:sessionId and
      // vice versa — so ordering does not matter here. For ambiguous siblings
      // (e.g. a static /history/export vs /history/:sessionId), always declare
      // the static route first.
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.sessionDetail,
        builder: (context, state) => SessionDetailScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),

      // Streak detail
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.streak,
        builder: (context, state) => const StreakDetailScreen(),
      ),

      // Exercise progress (sub-page of Progress tab, full-screen)
      GoRoute(
        parentNavigatorKey: _rootKey,
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

      // Profile sub-pages
      // Static segment 'edit' must come BEFORE parameterized siblings.
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.editProfile,
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        parentNavigatorKey: _rootKey,
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
  );
}
