import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironlog/app.dart';

void main() {
  testWidgets('IronLogApp renders splash screen while auth initializes',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: IronLogApp(),
      ),
    );

    // On first frame the auth state is AuthInitializing, so GoRouter stays on
    // the splash route which shows a loading spinner — no redirect yet.
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.fitness_center), findsOneWidget);
  });
}
