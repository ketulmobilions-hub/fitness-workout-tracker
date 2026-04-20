import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_workout_tracker/app.dart';

void main() {
  testWidgets('FitnessApp renders splash screen while auth initializes',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FitnessApp(),
      ),
    );

    // On first frame the auth state is AuthInitializing, so GoRouter stays on
    // the splash route which shows a loading spinner — no redirect yet.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
  });
}
