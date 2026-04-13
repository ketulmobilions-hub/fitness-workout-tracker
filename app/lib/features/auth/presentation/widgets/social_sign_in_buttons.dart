import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_notifier.dart';
import '../../providers/auth_state.dart';

/// Google Sign-In button. Visible on all platforms.
class GoogleSignInButton extends ConsumerWidget {
  const GoogleSignInButton({super.key, this.onError});

  final void Function(Object error)? onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(authProvider) is AuthLoading;

    return OutlinedButton.icon(
      onPressed: isLoading
          ? null
          : () async {
              try {
                await ref
                    .read(authProvider.notifier)
                    .signInWithGoogle();
              } catch (e) {
                onError?.call(e);
              }
            },
      icon: const _GoogleLogo(),
      label: const Text('Continue with Google'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}

/// Apple Sign-In button. Only visible on iOS and macOS.
class AppleSignInButton extends ConsumerWidget {
  const AppleSignInButton({super.key, this.onError});

  final void Function(Object error)? onError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return const SizedBox.shrink();
    }

    final isLoading = ref.watch(authProvider) is AuthLoading;

    return FilledButton.icon(
      onPressed: isLoading
          ? null
          : () async {
              try {
                await ref
                    .read(authProvider.notifier)
                    .signInWithApple();
              } catch (e) {
                onError?.call(e);
              }
            },
      icon: const Icon(Icons.apple, size: 20),
      label: const Text('Continue with Apple'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 48),
      ),
    );
  }
}

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    // Simple "G" text logo as a fallback — avoids adding an assets dependency.
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Color(0xFF4285F4),
      ),
    );
  }
}
