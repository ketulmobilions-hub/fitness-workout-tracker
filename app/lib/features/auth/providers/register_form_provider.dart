import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import 'auth_notifier.dart';

part 'register_form_provider.freezed.dart';
part 'register_form_provider.g.dart';

@freezed
abstract class RegisterFormState with _$RegisterFormState {
  const factory RegisterFormState({
    @Default('') String name,
    @Default('') String email,
    @Default('') String password,
    @Default('') String confirmPassword,
    @Default(false) bool isLoading,
    AppException? error,
    @Default({}) Map<String, List<String>> fieldErrors,
  }) = _RegisterFormState;
}

@riverpod
class RegisterFormNotifier extends _$RegisterFormNotifier {
  @override
  RegisterFormState build() => const RegisterFormState();

  void setName(String value) =>
      state = state.copyWith(name: value, fieldErrors: {}, error: null);

  void setEmail(String value) =>
      state = state.copyWith(email: value, fieldErrors: {}, error: null);

  void setPassword(String value) =>
      state = state.copyWith(password: value, fieldErrors: {}, error: null);

  void setConfirmPassword(String value) =>
      state = state.copyWith(
        confirmPassword: value,
        fieldErrors: {},
        error: null,
      );

  Future<void> submit() async {
    final errors = _validate();
    if (errors.isNotEmpty) {
      state = state.copyWith(fieldErrors: errors);
      return;
    }

    state = state.copyWith(isLoading: true, error: null, fieldErrors: {});
    try {
      await ref.read(authProvider.notifier).register(
            email: state.email.trim(),
            password: state.password,
            displayName: state.name.trim().isEmpty ? null : state.name.trim(),
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
    } else if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      errors['email'] = ['Enter a valid email address'];
    }
    if (state.password.isEmpty) {
      errors['password'] = ['Password is required'];
    } else if (state.password.length < 8) {
      errors['password'] = ['Password must be at least 8 characters'];
    }
    if (state.confirmPassword != state.password) {
      errors['confirmPassword'] = ["Passwords don't match"];
    }
    return errors;
  }
}
