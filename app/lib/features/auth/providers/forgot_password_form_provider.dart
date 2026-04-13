import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import 'auth_providers.dart';

part 'forgot_password_form_provider.freezed.dart';
part 'forgot_password_form_provider.g.dart';

@freezed
abstract class ForgotPasswordFormState with _$ForgotPasswordFormState {
  const factory ForgotPasswordFormState({
    @Default('') String email,
    @Default(false) bool isLoading,
    @Default(false) bool isSuccess,
    AppException? error,
    @Default({}) Map<String, List<String>> fieldErrors,
  }) = _ForgotPasswordFormState;
}

@riverpod
class ForgotPasswordFormNotifier extends _$ForgotPasswordFormNotifier {
  @override
  ForgotPasswordFormState build() => const ForgotPasswordFormState();

  void setEmail(String value) =>
      state = state.copyWith(email: value, fieldErrors: {}, error: null);

  Future<void> submit() async {
    final email = state.email.trim();
    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      state = state.copyWith(
        fieldErrors: {
          'email': ['Enter a valid email address'],
        },
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null, fieldErrors: {});
    try {
      await ref.read(authRepositoryProvider).forgotPassword(email: email);
      state = state.copyWith(isLoading: false, isSuccess: true);
    } on AppException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e,
        fieldErrors: switch (e) {
          ValidationException(:final fields) => fields ?? {},
          _ => {},
        },
      );
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        error: const AppException.unknown(),
      );
    }
  }
}
