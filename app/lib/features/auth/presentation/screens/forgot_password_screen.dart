import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/forgot_password_form_provider.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/auth_text_field.dart';

class ForgotPasswordScreen extends ConsumerWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(forgotPasswordFormProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: formState.isSuccess
                  ? _SuccessView(email: formState.email)
                  : _FormView(formState: formState),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormView extends ConsumerWidget {
  const _FormView({required this.formState});

  final ForgotPasswordFormState formState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset, size: 56),
        const SizedBox(height: 16),
        Text(
          'Forgot your password?',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email address and we'll send you a link to reset your password.",
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),

        AuthErrorBanner(error: formState.error),
        if (formState.error != null) const SizedBox(height: 16),

        AuthTextField(
          label: 'Email',
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.email],
          errorText: formState.fieldErrors['email']?.first,
          onChanged: ref
              .read(forgotPasswordFormProvider.notifier)
              .setEmail,
          onSubmitted: (_) =>
              ref.read(forgotPasswordFormProvider.notifier).submit(),
        ),
        const SizedBox(height: 24),

        FilledButton(
          onPressed: formState.isLoading
              ? null
              : () => ref
                  .read(forgotPasswordFormProvider.notifier)
                  .submit(),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: formState.isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Reset Link'),
        ),
      ],
    );
  }
}

class _SuccessView extends StatelessWidget {
  const _SuccessView({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_read_outlined, size: 64, color: Colors.green),
        const SizedBox(height: 16),
        Text(
          'Check your email',
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          "If $email is registered, you'll receive a password reset link shortly.",
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
          ),
          child: const Text('Back to Sign In'),
        ),
      ],
    );
  }
}
