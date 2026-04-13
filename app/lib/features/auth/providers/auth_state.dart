import 'package:fitness_domain/fitness_domain.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth_state.freezed.dart';

@freezed
sealed class AuthState with _$AuthState {
  /// Token check in-flight on cold start. Show splash screen.
  const factory AuthState.initializing() = AuthInitializing;

  /// No valid session. Show auth screens.
  const factory AuthState.unauthenticated() = AuthUnauthenticated;

  /// Login / register action in progress.
  const factory AuthState.loading() = AuthLoading;

  /// Signed in with a full account.
  const factory AuthState.authenticated({required AuthUser user}) = Authenticated;

  /// Signed in as an anonymous guest.
  const factory AuthState.guest({required AuthUser user}) = AuthGuest;
}
