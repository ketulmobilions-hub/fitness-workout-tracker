import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironlog/core/router/app_router.dart';
import 'package:ironlog/core/router/app_routes.dart';
import 'package:ironlog/features/auth/providers/auth_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const testUser = AuthUser(id: 'u1', email: 'a@b.com', isGuest: false);
  const guestUser = AuthUser(id: 'u2', email: null, isGuest: true);

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  // Most tests assume onboarding is complete (existing user flows).
  const done = AsyncData<bool>(true);
  const notDone = AsyncData<bool>(false);
  const loading = AsyncLoading<bool>();

  String? redirect(AuthState s, String location,
          [AsyncValue<bool> onboarding = done]) =>
      resolveAuthRedirect(s, onboarding, location);

  // ---------------------------------------------------------------------------
  // AuthInitializing — no redirects ever (stay on splash)
  // ---------------------------------------------------------------------------
  group('AuthInitializing', () {
    const state = AuthState.initializing();

    test('does not redirect from splash', () {
      expect(redirect(state, AppRoutes.splash), isNull);
    });

    test('does not redirect from a protected route', () {
      expect(redirect(state, AppRoutes.home), isNull);
    });

    test('does not redirect from an auth route', () {
      expect(redirect(state, AppRoutes.login), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AuthLoading — no redirects (action in progress)
  // ---------------------------------------------------------------------------
  group('AuthLoading', () {
    const state = AuthState.loading();

    test('does not redirect from login', () {
      expect(redirect(state, AppRoutes.login), isNull);
    });

    test('does not redirect from home', () {
      expect(redirect(state, AppRoutes.home), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AuthUnauthenticated — redirect to login unless already on auth page
  // ---------------------------------------------------------------------------
  group('AuthUnauthenticated', () {
    const state = AuthState.unauthenticated();

    test('does not redirect from login', () {
      expect(redirect(state, AppRoutes.login), isNull);
    });

    test('does not redirect from register', () {
      expect(redirect(state, AppRoutes.register), isNull);
    });

    test('does not redirect from forgot-password', () {
      expect(redirect(state, AppRoutes.forgotPassword), isNull);
    });

    test('does not redirect from reset-password', () {
      expect(redirect(state, AppRoutes.resetPassword), isNull);
    });

    test('does not redirect from reset-password with query parameters', () {
      // Deep-link: /auth/reset-password?token=<token> — must still be treated
      // as an auth page so the user is not redirected away mid-reset.
      expect(
        redirect(state, '${AppRoutes.resetPassword}?token=abc123'),
        isNull,
      );
    });

    test('redirects to login from splash', () {
      // Once auth has resolved to Unauthenticated, the token load is finished
      // (Initializing/Loading cover the in-flight case). Staying on splash
      // would leave the user stuck on the spinner forever.
      expect(redirect(state, AppRoutes.splash), AppRoutes.login);
    });

    test('redirects to login from a protected route', () {
      expect(redirect(state, AppRoutes.home), AppRoutes.login);
    });

    test('redirects to login from an unknown protected route', () {
      expect(redirect(state, '/some/other/page'), AppRoutes.login);
    });
  });

  // ---------------------------------------------------------------------------
  // Authenticated — redirect away from auth pages to home
  // ---------------------------------------------------------------------------
  group('Authenticated', () {
    const state = AuthState.authenticated(user: testUser);

    test('redirects from splash to home', () {
      expect(redirect(state, AppRoutes.splash), AppRoutes.home);
    });

    test('redirects from login to home', () {
      expect(redirect(state, AppRoutes.login), AppRoutes.home);
    });

    test('redirects from register to home', () {
      expect(redirect(state, AppRoutes.register), AppRoutes.home);
    });

    test('redirects from forgot-password to home', () {
      expect(redirect(state, AppRoutes.forgotPassword), AppRoutes.home);
    });

    test('does not redirect from a protected route', () {
      expect(redirect(state, AppRoutes.home), isNull);
    });

    test('does not redirect from an unknown protected route', () {
      expect(redirect(state, '/profile'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AuthGuest — same redirect rules as Authenticated
  // ---------------------------------------------------------------------------
  group('AuthGuest', () {
    const state = AuthState.guest(user: guestUser);

    test('redirects from splash to home', () {
      expect(redirect(state, AppRoutes.splash), AppRoutes.home);
    });

    test('redirects from login to home', () {
      expect(redirect(state, AppRoutes.login), AppRoutes.home);
    });

    test('does not redirect from a protected route', () {
      expect(redirect(state, AppRoutes.home), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Onboarding — first-launch redirect logic
  // ---------------------------------------------------------------------------
  group('Onboarding', () {
    const auth = AuthState.authenticated(user: testUser);

    test('redirects splash → onboarding when not done', () {
      expect(redirect(auth, AppRoutes.splash, notDone), AppRoutes.onboarding);
    });

    test('redirects auth flow → onboarding when not done', () {
      expect(
        redirect(auth, AppRoutes.login, notDone),
        AppRoutes.onboarding,
      );
    });

    test('stays on onboarding when not done', () {
      expect(redirect(auth, AppRoutes.onboarding, notDone), isNull);
    });

    test('redirects onboarding → home when already done', () {
      expect(redirect(auth, AppRoutes.onboarding, done), AppRoutes.home);
    });

    test('no redirect from protected route when already done', () {
      expect(redirect(auth, AppRoutes.home, done), isNull);
    });

    test('no redirect while onboarding state loading', () {
      expect(redirect(auth, AppRoutes.splash, loading), isNull);
    });

    test('no redirect from protected route while loading', () {
      expect(redirect(auth, AppRoutes.home, loading), isNull);
    });
  });
}
