import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitness_workout_tracker/app.dart';

void main() {
  testWidgets('FitnessApp renders', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: FitnessApp(),
      ),
    );

    expect(find.text('Fitness Tracker'), findsOneWidget);
  });
}
