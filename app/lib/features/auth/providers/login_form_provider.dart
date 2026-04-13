import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import 'auth_notifier.dart';

part 'login_form_provider.freezed.dart';
part 'login_form_provider.g.dart';

@freezed
abstract class LoginFormState with _$LoginFormState {
  const factory LoginFormState({
    @Default('') String email,
    @Default('') String password,
    @Default(false) bool isLoading,
    AppException? error,
    @Default({}) Map<String, List<String>> fieldErrors,
  }) = _LoginFormState;
}

@riverpod
class LoginFormNotifier extends _$LoginFormNotifier {
  @override
  LoginFormState build() => const LoginFormState();

  void setEmail(String value) =>
      state = state.copyWith(email: value, fieldErrors: {}, error: null);

  void setPassword(String value) =>
      state = state.copyWith(password: value, fieldErrors: {}, error: null);

  Future<void> submit() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return;
    }

    state = state.copyWith(isLoading: true, error: null, fieldErrors: {});
    try {
      await ref.read(authProvider.notifier).login(
            email: state.email.trim(),
            password: state.password,
          );
      state = state.copyWith(isLoading: false);
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
    final email = state.email.trim();
    if (email.isEmpty) {
      errors['email'] = ['Email is required'];
    } else if (!_isValidEmail(email)) {
      errors['email'] = ['Enter a valid email address'];
    }
    if (state.password.isEmpty) {
      errors['password'] = ['Password is required'];
    }
    return errors;
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  }
}
