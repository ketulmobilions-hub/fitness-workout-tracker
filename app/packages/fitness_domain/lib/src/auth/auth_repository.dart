import 'auth_user.dart';

/// Contract for all authentication operations.
///
/// Implementations call the remote API, persist tokens via [AuthTokenNotifier],
/// and persist the user row to the local Drift database. All methods throw
/// typed [AppException] subtypes on failure — callers pattern-match to show
/// appropriate UI feedback.
abstract interface class AuthRepository {
  /// Sign in with email and password.
  Future<AuthUser> login({
    required String email,
    required String password,
  });

  /// Create a new account with email and password.
  Future<AuthUser> register({
    required String email,
    required String password,
    String? displayName,
  });

  /// Sign in via Google OAuth (native flow via google_sign_in package).
  Future<AuthUser> signInWithGoogle();

  /// Sign in via Apple OAuth (native flow via sign_in_with_apple package).
  Future<AuthUser> signInWithApple();

  /// Create an anonymous guest account. Can be upgraded later.
  Future<AuthUser> signInAsGuest();

  /// Send a password reset email. Always succeeds regardless of email existence
  /// (server returns a generic message to prevent user enumeration).
  Future<void> forgotPassword({required String email});

  /// Complete a password reset using the token from the reset email.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  /// Clear all stored tokens and sign out.
  Future<void> logout();

  /// Exchange the current refresh token for new tokens. Called automatically
  /// by [RefreshInterceptor] on 401 responses — not a UI action.
  Future<void> refreshTokens();
}
