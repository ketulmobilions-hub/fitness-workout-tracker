abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';

  /// Deep-link target. Expects a `?token=<reset-token>` query parameter.
  static const resetPassword = '/auth/reset-password';

  static const home = '/home';

  // Exercise routes
  static const exercises = '/exercises';
  static const createExercise = '/exercises/create';
  static const exerciseDetail = '/exercises/:exerciseId';

  /// Returns the concrete path for navigating to a specific exercise detail
  /// screen, e.g. `/exercises/abc-123`.
  static String exerciseDetailPath(String id) => '/exercises/$id';

  // Workout plan routes
  static const plans = '/plans';

  /// Static route — must be registered BEFORE [planDetail] so GoRouter does
  /// not match the literal string "create" as a planId.
  static const createPlan = '/plans/create';

  static const planDetail = '/plans/:planId';
  static const editPlan = '/plans/:planId/edit';

  /// Returns the concrete path for navigating to a specific plan detail
  /// screen, e.g. `/plans/abc-123`.
  static String planDetailPath(String id) => '/plans/$id';

  /// Returns the concrete path for navigating to the edit screen for a plan.
  static String editPlanPath(String id) => '/plans/$id/edit';

  // Active workout routes
  static const activeWorkout = '/workout/active';
  static const workoutSummary = '/workout/summary';
}
