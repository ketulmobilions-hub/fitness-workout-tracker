import 'package:fitness_data/fitness_data.dart' as data;
import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/dio_provider.dart';
import '../data/training_max_repository_impl.dart';

part 'training_max_providers.g.dart';

@Riverpod(keepAlive: true)
data.TrainingMaxApiClient trainingMaxApiClient(Ref ref) =>
    data.TrainingMaxApiClient(ref.watch(dioProvider));

@Riverpod(keepAlive: true)
TrainingMaxRepository trainingMaxRepository(Ref ref) =>
    TrainingMaxRepositoryImpl(
      apiClient: ref.watch(trainingMaxApiClientProvider),
    );

@Riverpod(keepAlive: true)
class TrainingMaxNotifier extends _$TrainingMaxNotifier {
  @override
  Future<List<TrainingMax>> build() =>
      ref.watch(trainingMaxRepositoryProvider).fetchAll();

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final data = await ref.read(trainingMaxRepositoryProvider).fetchAll();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<TrainingMax> upsert({
    required String exerciseId,
    required double trainingMaxKg,
    required double percentageOf1rm,
  }) async {
    final updated = await ref.read(trainingMaxRepositoryProvider).upsert(
          exerciseId: exerciseId,
          trainingMaxKg: trainingMaxKg,
          percentageOf1rm: percentageOf1rm,
        );
    // Update local list — replace if exists, prepend if new.
    final current = state.value ?? [];
    final idx = current.indexWhere((t) => t.exerciseId == exerciseId);
    final next = [...current];
    if (idx >= 0) {
      next[idx] = updated;
    } else {
      next.insert(0, updated);
    }
    state = AsyncValue.data(next);
    return updated;
  }
}
