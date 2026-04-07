import 'package:drift/native.dart';
import 'package:fitness_data/fitness_data.dart';

AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
