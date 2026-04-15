import 'package:drift/drift.dart' show Value;
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';

class WorkoutPlanRepositoryImpl implements WorkoutPlanRepository {
  WorkoutPlanRepositoryImpl({
    required PlanApiClient apiClient,
    required WorkoutPlanDao planDao,
    required String userId,
  })  : _apiClient = apiClient,
        _planDao = planDao,
        _userId = userId;

  final PlanApiClient _apiClient;
  final WorkoutPlanDao _planDao;
  final String _userId;

  // ---------------------------------------------------------------------------
  // Read — streams from local Drift DB (offline-first)
  // ---------------------------------------------------------------------------

  @override
  Stream<List<WorkoutPlan>> watchPlans() {
    return _planDao
        .watchPlansForUser(_userId)
        .map((rows) => rows.map(_rowToPlan).toList());
  }

  @override
  Stream<WorkoutPlan?> watchPlan(String id) {
    // Uses Future-based DAO queries inside asyncMap (not .first on watch
    // streams, which can hang when a table is empty on first subscribe).
    return _planDao.watchPlan(id).asyncMap((row) async {
      if (row == null) return null;
      final dayRows = await _planDao.getDaysForPlan(id);
      final days = await Future.wait(
        dayRows.map((dayRow) async {
          final exerciseResults =
              await _planDao.getExercisesForPlanDayWithDetails(dayRow.id);
          final exercises = exerciseResults.map((result) {
            final ex = result.readTable(_planDao.planDayExercises);
            final exercise = result.readTable(_planDao.exercises);
            return PlanDayExercise(
              id: ex.id,
              exerciseId: ex.exerciseId,
              exerciseName: exercise.name,
              exerciseType: exercise.exerciseType,
              sortOrder: ex.sortOrder,
              targetSets: ex.targetSets,
              targetReps: ex.targetReps,
              targetDurationSec: ex.targetDurationSec,
              targetDistanceM: ex.targetDistanceM,
              notes: ex.notes,
            );
          }).toList();
          return PlanDay(
            id: dayRow.id,
            dayOfWeek: dayRow.dayOfWeek,
            weekNumber: dayRow.weekNumber == 0 ? null : dayRow.weekNumber,
            name: dayRow.name,
            sortOrder: dayRow.sortOrder,
            exercises: exercises,
          );
        }),
      );
      return _rowToPlan(row).copyWith(days: days);
    });
  }

  // ---------------------------------------------------------------------------
  // Sync — API → Drift
  // ---------------------------------------------------------------------------

  @override
  Future<void> syncPlans() async {
    final allPlans = <PlanDto>[];
    String? cursor;
    do {
      final response = await _apiClient.listPlans(
        cursor: cursor,
        limit: 100,
      );
      allPlans.addAll(response.data.plans);
      final nextCursor = response.data.pagination.nextCursor;
      cursor = (response.data.pagination.hasMore &&
              nextCursor != null &&
              nextCursor.isNotEmpty)
          ? nextCursor
          : null;
    } while (cursor != null);

    for (final dto in allPlans) {
      await _planDao.upsertPlan(_dtoToCompanion(dto));
    }
  }

  @override
  Future<void> syncPlanDetail(String id) async {
    final envelope = await _apiClient.getPlan(id);
    final dto = envelope.data.plan;

    await _planDao.transaction(() async {
      // Upsert the plan header.
      await _planDao.upsertPlan(_dtoToCompanion(dto));

      final apiDayIds = dto.days.map((d) => d.id).toSet();

      // There is no ON DELETE CASCADE on plan_day_exercises.plan_day_id, so
      // exercises for removed days must be deleted explicitly before their
      // parent day rows are deleted. Fetch local days now (inside the
      // transaction) to find which days the server removed.
      final localDays = await _planDao.getDaysForPlan(id);
      for (final localDay in localDays) {
        if (!apiDayIds.contains(localDay.id)) {
          // This day no longer exists on the server — wipe all its exercises.
          await _planDao.deletePlanDayExercisesNotInSet(localDay.id, {});
        }
      }

      for (final day in dto.days) {
        await _planDao.upsertPlanDay(
          PlanDaysCompanion(
            id: Value(day.id),
            planId: Value(id),
            dayOfWeek: Value(day.dayOfWeek),
            // 0 is the sentinel meaning "no week" for weekly plans (weekNumber
            // is non-nullable in SQLite). See workout_plan_tables.dart for the
            // authoritative note on this convention.
            weekNumber: Value(day.weekNumber ?? 0),
            name: Value(day.name),
            sortOrder: Value(day.sortOrder),
            updatedAt: Value(DateTime.now()),
          ),
        );

        final apiExerciseIds = day.exercises.map((e) => e.id).toSet();

        for (final ex in day.exercises) {
          await _planDao.upsertPlanDayExercise(
            PlanDayExercisesCompanion(
              id: Value(ex.id),
              planDayId: Value(day.id),
              exerciseId: Value(ex.exerciseId),
              sortOrder: Value(ex.sortOrder),
              targetSets: Value(ex.targetSets),
              targetReps: Value(ex.targetReps),
              targetDurationSec: Value(ex.targetDurationSec),
              targetDistanceM: Value(ex.targetDistanceM),
              notes: Value(ex.notes),
              createdAt: Value(ex.createdAt),
              updatedAt: Value(ex.updatedAt),
            ),
          );
        }

        // Remove exercises that exist locally but were deleted on the server.
        await _planDao.deletePlanDayExercisesNotInSet(day.id, apiExerciseIds);
      }

      // Remove days that no longer exist on the server (exercises already
      // cleaned up above).
      await _planDao.deletePlanDaysNotInSet(id, apiDayIds);
    });
  }

  // ---------------------------------------------------------------------------
  // Write — plan lifecycle
  // ---------------------------------------------------------------------------

  @override
  Future<WorkoutPlan> createPlan({
    required String name,
    String? description,
    required ScheduleType scheduleType,
    int? weeksCount,
    List<PlanDay>? initialDays,
  }) async {
    final scheduleTypeStr =
        const ScheduleTypeConverter().toSql(scheduleType);
    final body = CreatePlanRequestDto(
      name: name,
      description: description,
      scheduleType: scheduleTypeStr,
      weeksCount: weeksCount,
      days: initialDays
          ?.map(
            (d) => CreatePlanDayDto(
              dayOfWeek: d.dayOfWeek,
              weekNumber: d.weekNumber,
              name: d.name,
              sortOrder: d.sortOrder,
            ),
          )
          .toList(),
    );
    final envelope = await _apiClient.createPlan(body);
    final dto = envelope.data.plan;

    // Persist the new plan + its days to the local cache.
    await _planDao.upsertPlan(_dtoToCompanion(dto));
    for (final day in dto.days) {
      await _planDao.upsertPlanDay(
        PlanDaysCompanion(
          id: Value(day.id),
          planId: Value(dto.id),
          dayOfWeek: Value(day.dayOfWeek),
          weekNumber: Value(day.weekNumber ?? 0),
          name: Value(day.name),
          sortOrder: Value(day.sortOrder),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    return _dtoPlanWithDays(dto);
  }

  @override
  Future<WorkoutPlan> updatePlan({
    required String id,
    String? name,
    String? description,
    ScheduleType? scheduleType,
    int? weeksCount,
    bool? isActive,
  }) async {
    final body = UpdatePlanRequestDto(
      name: name,
      description: description,
      scheduleType: scheduleType != null
          ? const ScheduleTypeConverter().toSql(scheduleType)
          : null,
      weeksCount: weeksCount,
      isActive: isActive,
    );
    final envelope = await _apiClient.updatePlan(id, body);
    final dto = envelope.data.plan;

    await _planDao.upsertPlan(_dtoToCompanion(dto));
    return _dtoPlanWithDays(dto);
  }

  @override
  Future<void> deletePlan(String id) async {
    await _apiClient.deletePlan(id);

    // No ON DELETE CASCADE in Drift — clean up children manually.
    final days = await _planDao.getDaysForPlan(id);
    for (final day in days) {
      await _planDao.deletePlanDayExercisesNotInSet(day.id, {});
    }
    await _planDao.deletePlanDaysNotInSet(id, {});
    await _planDao.deletePlan(id);
  }

  // ---------------------------------------------------------------------------
  // Write — exercises within a plan day
  // ---------------------------------------------------------------------------

  @override
  Future<PlanDayExercise> addExerciseToDay({
    required String planId,
    required String planDayId,
    required String exerciseId,
    required int sortOrder,
    int? targetSets,
    String? targetReps,
    int? targetDurationSec,
    double? targetDistanceM,
    String? notes,
  }) async {
    final body = AddPlanExerciseRequestDto(
      planDayId: planDayId,
      exerciseId: exerciseId,
      sortOrder: sortOrder,
      targetSets: targetSets,
      targetReps: targetReps,
      targetDurationSec: targetDurationSec,
      targetDistanceM: targetDistanceM,
      notes: notes,
    );
    final envelope = await _apiClient.addExercise(planId, body);
    final dto = envelope.data.plan;

    // Find the newly created exercise in the response (last one with matching
    // exerciseId in the target day).
    final dayDto = dto.days.firstWhere(
      (d) => d.id == planDayId,
      orElse: () => throw StateError(
        'addExercise response did not contain day $planDayId',
      ),
    );

    // Upsert all exercises for this day so the local cache stays in sync.
    for (final ex in dayDto.exercises) {
      await _planDao.upsertPlanDayExercise(
        PlanDayExercisesCompanion(
          id: Value(ex.id),
          planDayId: Value(planDayId),
          exerciseId: Value(ex.exerciseId),
          sortOrder: Value(ex.sortOrder),
          targetSets: Value(ex.targetSets),
          targetReps: Value(ex.targetReps),
          targetDurationSec: Value(ex.targetDurationSec),
          targetDistanceM: Value(ex.targetDistanceM),
          notes: Value(ex.notes),
          createdAt: Value(ex.createdAt),
          updatedAt: Value(ex.updatedAt),
        ),
      );
    }

    // Return the exercise that was just added (last one for this exerciseId).
    final added = dayDto.exercises.lastWhere(
      (e) => e.exerciseId == exerciseId,
    );
    return _dtoToExerciseDomain(added);
  }

  @override
  Future<PlanDayExercise> updatePlanExercise({
    required String planId,
    required String planDayExerciseId,
    int? sortOrder,
    int? targetSets,
    String? targetReps,
    int? targetDurationSec,
    double? targetDistanceM,
    String? notes,
  }) async {
    final body = UpdatePlanExerciseRequestDto(
      sortOrder: sortOrder,
      targetSets: targetSets,
      targetReps: targetReps,
      targetDurationSec: targetDurationSec,
      targetDistanceM: targetDistanceM,
      notes: notes,
    );
    final envelope =
        await _apiClient.updateExercise(planId, planDayExerciseId, body);
    final dto = envelope.data.plan;

    // Find the updated exercise across all days and upsert it.
    PlanDayExerciseDto? updatedDto;
    for (final day in dto.days) {
      for (final ex in day.exercises) {
        if (ex.id == planDayExerciseId) {
          updatedDto = ex;
          await _planDao.upsertPlanDayExercise(
            PlanDayExercisesCompanion(
              id: Value(ex.id),
              planDayId: Value(day.id),
              exerciseId: Value(ex.exerciseId),
              sortOrder: Value(ex.sortOrder),
              targetSets: Value(ex.targetSets),
              targetReps: Value(ex.targetReps),
              targetDurationSec: Value(ex.targetDurationSec),
              targetDistanceM: Value(ex.targetDistanceM),
              notes: Value(ex.notes),
              createdAt: Value(ex.createdAt),
              updatedAt: Value(ex.updatedAt),
            ),
          );
          break;
        }
      }
      if (updatedDto != null) break;
    }

    if (updatedDto == null) {
      throw StateError(
        'updateExercise response did not contain exercise $planDayExerciseId',
      );
    }
    return _dtoToExerciseDomain(updatedDto);
  }

  @override
  Future<void> deletePlanExercise({
    required String planId,
    required String planDayExerciseId,
  }) async {
    await _apiClient.deleteExercise(planId, planDayExerciseId);
    await _planDao.deletePlanDayExercise(planDayExerciseId);
  }

  @override
  Future<void> reorderDayExercises({
    required String planId,
    required String planDayId,
    required List<String> orderedExerciseIds,
  }) async {
    final body = ReorderPlanExercisesRequestDto(
      planDayId: planDayId,
      planDayExerciseIds: orderedExerciseIds,
    );
    await _apiClient.reorderExercises(planId, body);
    await _planDao.reorderPlanDayExercises(planDayId, orderedExerciseIds);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  WorkoutPlan _rowToPlan(WorkoutPlanRow row) {
    return WorkoutPlan(
      id: row.id,
      name: row.name,
      description: row.description,
      isActive: row.isActive,
      scheduleType: row.scheduleType,
      weeksCount: row.weeksCount,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  WorkoutPlansCompanion _dtoToCompanion(PlanDto dto) {
    return WorkoutPlansCompanion(
      id: Value(dto.id),
      userId: Value(_userId),
      name: Value(dto.name),
      description: Value(dto.description),
      isActive: Value(dto.isActive),
      // Use the shared converter for consistent parsing and fallback logging.
      scheduleType: Value(const ScheduleTypeConverter().fromSql(dto.scheduleType)),
      weeksCount: Value(dto.weeksCount),
      createdAt: Value(dto.createdAt),
      updatedAt: Value(dto.updatedAt),
    );
  }

  /// Converts a [PlanDto] (which may contain day stubs from a create/update
  /// response) to a domain [WorkoutPlan] without hitting Drift.
  WorkoutPlan _dtoPlanWithDays(PlanDto dto) {
    return WorkoutPlan(
      id: dto.id,
      name: dto.name,
      description: dto.description,
      isActive: dto.isActive,
      scheduleType: const ScheduleTypeConverter().fromSql(dto.scheduleType),
      weeksCount: dto.weeksCount,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
      days: dto.days
          .map(
            (d) => PlanDay(
              id: d.id,
              dayOfWeek: d.dayOfWeek,
              weekNumber: d.weekNumber,
              name: d.name,
              sortOrder: d.sortOrder,
              exercises: d.exercises.map(_dtoToExerciseDomain).toList(),
            ),
          )
          .toList(),
    );
  }

  PlanDayExercise _dtoToExerciseDomain(PlanDayExerciseDto dto) {
    return PlanDayExercise(
      id: dto.id,
      exerciseId: dto.exerciseId,
      exerciseName: dto.exerciseName,
      exerciseType: const ExerciseTypeConverter().fromSql(dto.exerciseType),
      sortOrder: dto.sortOrder,
      targetSets: dto.targetSets,
      targetReps: dto.targetReps,
      targetDurationSec: dto.targetDurationSec,
      targetDistanceM: dto.targetDistanceM,
      notes: dto.notes,
    );
  }
}
