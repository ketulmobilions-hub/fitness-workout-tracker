abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/auth/login';
  static const register = '/auth/register';
  static const forgotPassword = '/auth/forgot-password';

  /// Deep-link target. Expects a `?token=<reset-token>` query parameter.
  static const resetPassword = '/auth/reset-password';

  static const home = '/home';
}
