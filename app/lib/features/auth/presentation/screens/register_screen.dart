import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';

import '../../providers/auth_notifier.dart';
import '../../providers/auth_state.dart';
import '../../providers/register_form_provider.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_text_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(registerFormProvider);
    final authState = ref.watch(authProvider);
    final isLoading = formState.isLoading || authState is AuthLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Join Fitness Tracker',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  AuthErrorBanner(error: formState.error),
                  if (formState.error != null) const SizedBox(height: 16),

                  AuthTextField(
                    label: 'Name (optional)',
                    keyboardType: TextInputType.name,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    errorText: formState.fieldErrors['displayName']?.first,
                    onChanged: ref
                        .read(registerFormProvider.notifier)
                        .setName,
                  ),
                  const SizedBox(height: 16),

                  AuthTextField(
                    label: 'Email',
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    errorText: formState.fieldErrors['email']?.first,
                    onChanged: ref
                        .read(registerFormProvider.notifier)
                        .setEmail,
                  ),
                  const SizedBox(height: 16),

                  AuthTextField(
                    label: 'Password',
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    errorText: formState.fieldErrors['password']?.first,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    onChanged: ref
                        .read(registerFormProvider.notifier)
                        .setPassword,
                  ),
                  const SizedBox(height: 16),

                  AuthTextField(
                    label: 'Confirm Password',
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    errorText: formState.fieldErrors['confirmPassword']?.first,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                    onChanged: ref
                        .read(registerFormProvider.notifier)
                        .setConfirmPassword,
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),

                  FilledButton(
                    onPressed: isLoading ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Account'),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : context.go(AppRoutes.login),
                        child: const Text('Sign in'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _submit() {
    ref.read(registerFormProvider.notifier).submit();
  }
}
