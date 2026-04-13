import 'dart:convert';

import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/providers/auth_token_provider.dart';
import '../../../core/providers/database_provider.dart';
import 'auth_providers.dart';
import 'auth_state.dart';

part 'auth_notifier.g.dart';

@Riverpod(keepAlive: true)
class AuthNotifier extends _$AuthNotifier {
  // Incremented whenever build() starts a new _restoreSession() or whenever
  // an action method (login/register/etc.) writes its own final state.
  // _restoreSession() captures its generation at call time and guards every
  // state write with _isLive(gen), so a newer build() or action method can
  // take ownership without a race.
  int _generation = 0;

  // Set true by ref.onDispose so _restoreSession() never writes state after
  // the provider has been torn down (tests, hot-restart).
  bool _disposed = false;

  @override
  AuthState build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);

    final tokenAsync = ref.watch(authTokenProvider);

    return tokenAsync.when(
      loading: () => const AuthState.initializing(),
      error: (err, _) => const AuthState.unauthenticated(),
      data: (token) {
        if (token == null) return const AuthState.unauthenticated();
        // Capture generation before the async gap so _restoreSession can
        // detect if it has been superseded (e.g. build() fires again after
        // setTokens() during login, or an action method beat it to the state).
        final gen = ++_generation;
        _restoreSession(token.accessToken, gen);
        return const AuthState.loading();
      },
    );
  }

  /// Looks up the persisted user row from Drift using the JWT sub claim and
  /// sets state imperatively. Guards every write with [_isLive] so it cannot
  /// overwrite a state that was set by an action method or a newer build().
  Future<void> _restoreSession(String accessToken, int generation) async {
    // Yield to the event loop before writing any state. build() calls this
    // method without await, so without this yield the first state write could
    // happen while build() has not yet returned — at which point Riverpod
    // drops the assignment because the provider is still in its build phase.
    // All non-trivial paths already have a natural await (the DB read), but
    // the early-return path (null sub, malformed JWT) does not.
    await Future<void>.delayed(Duration.zero);
    final userId = _extractSubFromJwt(accessToken);
    if (userId == null) {
      _setStateGuarded(const AuthState.unauthenticated(), generation);
      return;
    }
    try {
      final userRow = await ref
          .read(appDatabaseProvider)
          .userDao
          .getUser(userId);
      if (!_isLive(generation)) return;
      if (userRow == null) {
        state = const AuthState.unauthenticated();
        return;
      }
      final user = AuthUser(
        id: userRow.id,
        email: userRow.email.startsWith('guest:') ? null : userRow.email,
        displayName: userRow.displayName,
        isGuest: userRow.isGuest,
      );
      state = userRow.isGuest
          ? AuthState.guest(user: user)
          : AuthState.authenticated(user: user);
    } catch (_) {
      _setStateGuarded(const AuthState.unauthenticated(), generation);
    }
  }

  /// Returns true only if [generation] is still the current one and the
  /// provider has not been disposed.
  bool _isLive(int generation) => !_disposed && _generation == generation;

  void _setStateGuarded(AuthState s, int generation) {
    if (_isLive(generation)) state = s;
  }

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final previous = state;
    state = const AuthState.loading();
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(email: email, password: password);
      // Bump generation to cancel any in-flight _restoreSession that was
      // triggered by setTokens() inside the repository call.
      _generation++;
      state = AuthState.authenticated(user: user);
    } on CancelledException {
      _generation++;
      state = previous;
      rethrow;
    } catch (_) {
      _generation++;
      state = const AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> register({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final previous = state;
    state = const AuthState.loading();
    try {
      final user = await ref.read(authRepositoryProvider).register(
            email: email,
            password: password,
            displayName: displayName,
          );
      _generation++;
      state = AuthState.authenticated(user: user);
    } on CancelledException {
      _generation++;
      state = previous;
      rethrow;
    } catch (_) {
      _generation++;
      state = const AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signInWithGoogle() async {
    final previous = state;
    state = const AuthState.loading();
    try {
      final user = await ref.read(authRepositoryProvider).signInWithGoogle();
      _generation++;
      state = AuthState.authenticated(user: user);
    } on CancelledException {
      // User dismissed the Google picker — restore prior state, don't redirect.
      _generation++;
      state = previous;
      rethrow;
    } catch (_) {
      _generation++;
      state = const AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signInWithApple() async {
    final previous = state;
    state = const AuthState.loading();
    try {
      final user = await ref.read(authRepositoryProvider).signInWithApple();
      _generation++;
      state = AuthState.authenticated(user: user);
    } on CancelledException {
      // User dismissed the Apple sheet — restore prior state, don't redirect.
      _generation++;
      state = previous;
      rethrow;
    } catch (_) {
      _generation++;
      state = const AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> signInAsGuest() async {
    final previous = state;
    state = const AuthState.loading();
    try {
      final user = await ref.read(authRepositoryProvider).signInAsGuest();
      _generation++;
      state = AuthState.guest(user: user);
    } on CancelledException {
      _generation++;
      state = previous;
      rethrow;
    } catch (_) {
      _generation++;
      state = const AuthState.unauthenticated();
      rethrow;
    }
  }

  Future<void> logout() async {
    _generation++;
    state = const AuthState.unauthenticated();
    await ref.read(authRepositoryProvider).logout();
  }
}

/// Extracts the `sub` (user ID) claim from a JWT payload without verifying
/// the signature. Used only for local DB lookup — the server verifies
/// signatures on every authenticated request.
String? _extractSubFromJwt(String jwt) {
  try {
    final parts = jwt.split('.');
    if (parts.length != 3) return null;
    // JWT uses base64url — convert to standard base64 and add padding.
    var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
    while (payload.length % 4 != 0) {
      payload += '=';
    }
    final decoded = utf8.decode(base64.decode(payload));
    final map = jsonDecode(decoded) as Map<String, dynamic>;
    return map['sub'] as String?;
  } catch (_) {
    return null;
  }
}
