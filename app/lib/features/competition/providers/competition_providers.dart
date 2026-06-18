import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/providers/dio_provider.dart';
import '../data/competition_repository_impl.dart';

part 'competition_providers.g.dart';

@Riverpod(keepAlive: true)
CompetitionApiClient competitionApiClient(Ref ref) {
  return CompetitionApiClient(ref.watch(dioProvider));
}

@Riverpod(keepAlive: true)
CompetitionRepository competitionRepository(Ref ref) {
  return CompetitionRepositoryImpl(
    apiClient: ref.watch(competitionApiClientProvider),
  );
}

// ---------------------------------------------------------------------------
// Competition list — all user competitions
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class CompetitionListNotifier extends _$CompetitionListNotifier {
  @override
  Future<List<Competition>> build() {
    return ref.watch(competitionRepositoryProvider).fetchAll();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final data = await ref.read(competitionRepositoryProvider).fetchAll();
      state = AsyncValue.data(data);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Competition> create({
    required String name,
    String? federation,
    required String date,
    String? location,
    double? weightClassKg,
    double? bodyweightKg,
    String? division,
  }) async {
    final comp = await ref.read(competitionRepositoryProvider).create(
          name: name,
          federation: federation,
          date: date,
          location: location,
          weightClassKg: weightClassKg,
          bodyweightKg: bodyweightKg,
          division: division,
        );
    final current = state.value ?? [];
    state = AsyncValue.data([comp, ...current]);
    return comp;
  }

  void updateOne(Competition comp) {
    final current = state.value;
    if (current == null) return;
    state = AsyncValue.data(
      current.map((c) => c.id == comp.id ? comp : c).toList(),
    );
  }
}

// ---------------------------------------------------------------------------
// Active meet — single competition being tracked in meet day mode
// ---------------------------------------------------------------------------

@Riverpod(keepAlive: true)
class ActiveMeetNotifier extends _$ActiveMeetNotifier {
  @override
  Competition? build() => null;

  void setMeet(Competition comp) => state = comp;
  void clearMeet() => state = null;

  Future<void> logAttempt({
    required String liftType,
    required int attemptNumber,
    required double weightKg,
    required String result,
  }) async {
    final current = state;
    if (current == null) return;

    // Optimistic update — reflect the attempt immediately before the round-trip.
    // If the POST succeeds but the re-fetch fails, the cell stays filled (correct)
    // rather than rolling back to empty and hiding a saved lift.
    final lt = switch (liftType) {
      'squat' => LiftType.squat,
      'bench' => LiftType.bench,
      _ => LiftType.deadlift,
    };
    final ar = switch (result) {
      'good_lift' => AttemptResult.goodLift,
      'no_lift' => AttemptResult.noLift,
      _ => AttemptResult.notTaken,
    };
    state = current.copyWith(
      attempts: [
        ...current.attempts.where(
          (a) => !(a.liftType == lt && a.attemptNumber == attemptNumber),
        ),
        CompetitionAttempt(
          id: '',
          liftType: lt,
          attemptNumber: attemptNumber,
          weightKg: weightKg,
          result: ar,
        ),
      ],
    );

    try {
      final updated = await ref.read(competitionRepositoryProvider).logAttempt(
            competitionId: current.id,
            liftType: liftType,
            attemptNumber: attemptNumber,
            weightKg: weightKg,
            result: result,
          );
      state = updated;
      ref.read(competitionListProvider.notifier).updateOne(updated);
    } catch (e) {
      // Don't revert optimistic state — if the write succeeded but the re-fetch
      // failed, the attempt IS on the server; rolling back would hide a saved lift.
      rethrow;
    }
  }
}
