import 'package:flutter/material.dart';

/// Initial screen shown while the app resolves auth state from secure storage.
/// GoRouter's redirect handles navigation once [AuthNotifier] emits a non-
/// initializing state — no action needed here.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 72),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
