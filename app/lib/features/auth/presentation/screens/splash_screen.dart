import 'package:flutter/material.dart';

/// Initial screen shown while the app resolves auth state from secure storage.
/// GoRouter's redirect handles navigation once [AuthNotifier] emits a non-
/// initializing state — no action needed here.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 72, color: cs.primary),
            const SizedBox(height: 16),
            Text(
              'IronLog',
              style: tt.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: cs.primary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 48),
            CircularProgressIndicator(color: cs.primary),
          ],
        ),
      ),
    );
  }
}
