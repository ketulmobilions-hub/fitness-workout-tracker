import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import 'auth_providers.dart';

part 'reset_password_form_provider.freezed.dart';
part 'reset_password_form_provider.g.dart';

@freezed
abstract class ResetPasswordFormState with _$ResetPasswordFormState {
  const factory ResetPasswordFormState({
    @Default('') String newPassword,
    @Default('') String confirmPassword,
    @Default(false) bool isLoading,
    @Default(false) bool isSuccess,
    AppException? error,
    @Default({}) Map<String, List<String>> fieldErrors,
  }) = _ResetPasswordFormState;
}

@riverpod
class ResetPasswordFormNotifier extends _$ResetPasswordFormNotifier {
  @override
  ResetPasswordFormState build() => const ResetPasswordFormState();

  void setNewPassword(String value) =>
      state = state.copyWith(newPassword: value, fieldErrors: {}, error: null);

  void setConfirmPassword(String value) =>
      state = state.copyWith(
        confirmPassword: value,
        fieldErrors: {},
        error: null,
      );

  Future<void> submit({required String token}) async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return;
    }

    state = state.copyWith(isLoading: true, error: null, fieldErrors: {});
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            token: token,
            newPassword: state.newPassword,
          );
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

  Map<String, List<String>> _validate() {
    final errors = <String, List<String>>{};
    if (state.newPassword.isEmpty) {
      errors['newPassword'] = ['Password is required'];
    } else if (state.newPassword.length < 8) {
      errors['newPassword'] = ['Password must be at least 8 characters'];
    }
    if (state.confirmPassword != state.newPassword) {
      errors['confirmPassword'] = ["Passwords don't match"];
    }
    return errors;
  }
}
