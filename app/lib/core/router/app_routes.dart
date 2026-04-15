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
  static const planDetail = '/plans/:planId';

  /// Returns the concrete path for navigating to a specific plan detail
  /// screen, e.g. `/plans/abc-123`.
  static String planDetailPath(String id) => '/plans/$id';
}
