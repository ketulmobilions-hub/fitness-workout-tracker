import 'package:drift/drift.dart' show Value;
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/sync/sync_service.dart';

const _uuid = Uuid();

class WorkoutPlanRepositoryImpl implements WorkoutPlanRepository {
  WorkoutPlanRepositoryImpl({
    required PlanApiClient apiClient,
    required WorkoutPlanDao planDao,
    required SyncQueueDao syncQueueDao,
    required String userId,
  })  : _apiClient = apiClient,
        _planDao = planDao,
        _syncDao = syncQueueDao,
        _userId = userId;

  final PlanApiClient _apiClient;
  final WorkoutPlanDao _planDao;
  final SyncQueueDao _syncDao;
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
    final scheduleTypeStr = const ScheduleTypeConverter().toSql(scheduleType);
    final localId = _uuid.v4();
    final now = DateTime.now();

    // ── Write locally first (offline-first) ──────────────────────────────────
    await _planDao.upsertPlan(WorkoutPlansCompanion(
      id: Value(localId),
      userId: Value(_userId),
      name: Value(name),
      description: Value(description),
      isActive: const Value(false),
      scheduleType: Value(scheduleType),
      weeksCount: Value(weeksCount),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    // ── Sync to server (best-effort) ─────────────────────────────────────────
    try {
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
      final dto = (await _apiClient.createPlan(body)).data.plan;

      // Server assigned its own UUID — replace local stub with server record.
      if (dto.id != localId) {
        await _planDao.transaction(() async {
          // Issue 10: defensively clean up child rows for localId before
          // deleting the stub plan. initialDays are not written locally
          // (only sent to the server), but if future code changes that this
          // guard prevents FK-violation errors.
          final localDays = await _planDao.getDaysForPlan(localId);
          for (final day in localDays) {
            await _planDao.deletePlanDayExercisesNotInSet(day.id, {});
          }
          await _planDao.deletePlanDaysNotInSet(localId, {});
          await _planDao.deletePlan(localId);
          await _planDao.upsertPlan(_dtoToCompanion(dto));
        });
      }
      for (final day in dto.days) {
        await _planDao.upsertPlanDay(
          PlanDaysCompanion(
            id: Value(day.id),
            planId: Value(dto.id),
            dayOfWeek: Value(day.dayOfWeek),
            weekNumber: Value(day.weekNumber ?? 0),
            name: Value(day.name),
            sortOrder: Value(day.sortOrder),
            updatedAt: Value(now),
          ),
        );
      }
      return _dtoPlanWithDays(dto);
    } catch (e) {
      debugPrint('WorkoutPlanRepository: createPlan server sync failed: $e');
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'workout_plans',
        recordId: localId,
        operation: SyncOperation.create,
        payload: {
          'name': name,
          if (description != null) 'description': description,
          'isActive': false,
          'scheduleType': scheduleTypeStr,
          if (weeksCount != null) 'weeksCount': weeksCount,
        },
      );
    }

    return WorkoutPlan(
      id: localId,
      name: name,
      description: description,
      isActive: false,
      scheduleType: scheduleType,
      weeksCount: weeksCount,
      createdAt: now,
      updatedAt: now,
    );
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
    // ── Write locally first (offline-first) ──────────────────────────────────
    await _planDao.upsertPlan(WorkoutPlansCompanion(
      id: Value(id),
      name: name != null ? Value(name) : const Value.absent(),
      description:
          description != null ? Value(description) : const Value.absent(),
      scheduleType:
          scheduleType != null ? Value(scheduleType) : const Value.absent(),
      weeksCount:
          weeksCount != null ? Value(weeksCount) : const Value.absent(),
      isActive: isActive != null ? Value(isActive) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));

    // ── Sync to server (best-effort) ─────────────────────────────────────────
    try {
      final body = UpdatePlanRequestDto(
        name: name,
        description: description,
        scheduleType: scheduleType != null
            ? const ScheduleTypeConverter().toSql(scheduleType)
            : null,
        weeksCount: weeksCount,
        isActive: isActive,
      );
      final dto = (await _apiClient.updatePlan(id, body)).data.plan;
      await _planDao.upsertPlan(_dtoToCompanion(dto));
      return _dtoPlanWithDays(dto);
    } catch (e) {
      debugPrint('WorkoutPlanRepository: updatePlan server sync failed: $e');
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'workout_plans',
        recordId: id,
        operation: SyncOperation.update,
        payload: {
          if (name != null) 'name': name,
          if (description != null) 'description': description,
          if (scheduleType != null)
            'scheduleType': const ScheduleTypeConverter().toSql(scheduleType),
          if (weeksCount != null) 'weeksCount': weeksCount,
          if (isActive != null) 'isActive': isActive,
        },
      );
    }

    // Issue 11: use one-shot getPlan() instead of watchPlan(id).first.
    // watchPlan().first opens a reactive stream subscription then tears it
    // down immediately — wasteful, and can hang if the table is empty on first
    // subscribe (the stream only emits on writes, not on initial query).
    final row = await _planDao.getPlan(id);
    return row != null ? _rowToPlan(row) : WorkoutPlan(
      id: id,
      name: name ?? '',
      isActive: isActive ?? false,
      scheduleType: scheduleType ?? ScheduleType.weekly,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  @override
  Future<void> deletePlan(String id) async {
    // ── Delete locally first (offline-first) ─────────────────────────────────
    // No ON DELETE CASCADE in Drift — clean up children manually.
    final days = await _planDao.getDaysForPlan(id);
    for (final day in days) {
      await _planDao.deletePlanDayExercisesNotInSet(day.id, {});
    }
    await _planDao.deletePlanDaysNotInSet(id, {});
    await _planDao.deletePlan(id);

    // ── Sync to server (best-effort) ─────────────────────────────────────────
    try {
      await _apiClient.deletePlan(id);
    } catch (e) {
      debugPrint('WorkoutPlanRepository: deletePlan server sync failed: $e');
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'workout_plans',
        recordId: id,
        operation: SyncOperation.delete,
        payload: {},
      );
    }
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
    final localId = _uuid.v4();
    final now = DateTime.now();

    // ── Write locally first (offline-first) ──────────────────────────────────
    await _planDao.upsertPlanDayExercise(PlanDayExercisesCompanion(
      id: Value(localId),
      planDayId: Value(planDayId),
      exerciseId: Value(exerciseId),
      sortOrder: Value(sortOrder),
      targetSets: Value(targetSets),
      targetReps: Value(targetReps),
      targetDurationSec: Value(targetDurationSec),
      targetDistanceM: Value(targetDistanceM),
      notes: Value(notes),
      createdAt: Value(now),
      updatedAt: Value(now),
    ));

    // ── Sync to server (best-effort) ─────────────────────────────────────────
    try {
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
      final dto = (await _apiClient.addExercise(planId, body)).data.plan;

      final dayDto = dto.days.firstWhere(
        (d) => d.id == planDayId,
        orElse: () =>
            throw StateError('addExercise response did not contain day $planDayId'),
      );

      // Upsert all exercises for this day so the local cache stays in sync.
      // If server assigned a different UUID for the new exercise, delete the
      // local stub first (no FK children on plan_day_exercises).
      final added = dayDto.exercises.lastWhere((e) => e.exerciseId == exerciseId);
      if (added.id != localId) {
        await _planDao.deletePlanDayExercise(localId);
      }
      for (final ex in dayDto.exercises) {
        await _planDao.upsertPlanDayExercise(PlanDayExercisesCompanion(
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
        ));
      }
      return _dtoToExerciseDomain(added);
    } catch (e) {
      debugPrint('WorkoutPlanRepository: addExerciseToDay server sync failed: $e');
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'plan_day_exercises',
        recordId: localId,
        operation: SyncOperation.create,
        payload: {
          'planDayId': planDayId,
          'exerciseId': exerciseId,
          'sortOrder': sortOrder,
          if (targetSets != null) 'targetSets': targetSets,
          if (targetReps != null) 'targetReps': targetReps,
          if (targetDurationSec != null) 'targetDurationSec': targetDurationSec,
          if (targetDistanceM != null) 'targetDistanceM': targetDistanceM,
          if (notes != null) 'notes': notes,
        },
      );
    }

    // Issue 12: look up exercise name and type from local exercise library so
    // the returned domain object is complete. The exercise row must be in Drift
    // (it was seeded from the server's exercise catalogue at first launch).
    final exerciseRow = await _planDao.getExerciseById(exerciseId);
    return PlanDayExercise(
      id: localId,
      exerciseId: exerciseId,
      exerciseName: exerciseRow?.name ?? '',
      exerciseType: exerciseRow?.exerciseType ?? ExerciseType.strength,
      sortOrder: sortOrder,
      targetSets: targetSets,
      targetReps: targetReps,
      targetDurationSec: targetDurationSec,
      targetDistanceM: targetDistanceM,
      notes: notes,
    );
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
    // ── Write locally first (offline-first) ──────────────────────────────────
    await _planDao.upsertPlanDayExercise(PlanDayExercisesCompanion(
      id: Value(planDayExerciseId),
      sortOrder: sortOrder != null ? Value(sortOrder) : const Value.absent(),
      targetSets:
          targetSets != null ? Value(targetSets) : const Value.absent(),
      targetReps:
          targetReps != null ? Value(targetReps) : const Value.absent(),
      targetDurationSec: targetDurationSec != null
          ? Value(targetDurationSec)
          : const Value.absent(),
      targetDistanceM: targetDistanceM != null
          ? Value(targetDistanceM)
          : const Value.absent(),
      notes: notes != null ? Value(notes) : const Value.absent(),
      updatedAt: Value(DateTime.now()),
    ));

    // ── Sync to server (best-effort) ─────────────────────────────────────────
    try {
      final body = UpdatePlanExerciseRequestDto(
        sortOrder: sortOrder,
        targetSets: targetSets,
        targetReps: targetReps,
        targetDurationSec: targetDurationSec,
        targetDistanceM: targetDistanceM,
        notes: notes,
      );
      final dto =
          (await _apiClient.updateExercise(planId, planDayExerciseId, body))
              .data
              .plan;

      PlanDayExerciseDto? updatedDto;
      for (final day in dto.days) {
        for (final ex in day.exercises) {
          if (ex.id == planDayExerciseId) {
            updatedDto = ex;
            await _planDao.upsertPlanDayExercise(PlanDayExercisesCompanion(
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
            ));
            break;
          }
        }
        if (updatedDto != null) break;
      }
      if (updatedDto == null) {
        throw StateError(
            'updateExercise response did not contain exercise $planDayExerciseId');
      }
      return _dtoToExerciseDomain(updatedDto);
    } catch (e) {
      debugPrint('WorkoutPlanRepository: updatePlanExercise server sync failed: $e');
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'plan_day_exercises',
        recordId: planDayExerciseId,
        operation: SyncOperation.update,
        payload: {
          if (sortOrder != null) 'sortOrder': sortOrder,
          if (targetSets != null) 'targetSets': targetSets,
          if (targetReps != null) 'targetReps': targetReps,
          if (targetDurationSec != null) 'targetDurationSec': targetDurationSec,
          if (targetDistanceM != null) 'targetDistanceM': targetDistanceM,
          if (notes != null) 'notes': notes,
        },
      );
    }

    // Issue 12: look up the local PlanDayExercise row to get exerciseId, then
    // resolve the exercise name/type from the local exercise library. This
    // avoids returning a domain object with empty exerciseId/exerciseName which
    // can cause null-pointer errors in any caller that expects real values.
    final localEx = await _planDao.getPlanDayExercise(planDayExerciseId);
    final exerciseRow = localEx != null
        ? await _planDao.getExerciseById(localEx.exerciseId)
        : null;
    return PlanDayExercise(
      id: planDayExerciseId,
      exerciseId: localEx?.exerciseId ?? '',
      exerciseName: exerciseRow?.name ?? '',
      exerciseType: exerciseRow?.exerciseType ?? ExerciseType.strength,
      sortOrder: sortOrder ?? localEx?.sortOrder ?? 0,
      targetSets: targetSets ?? localEx?.targetSets,
      targetReps: targetReps ?? localEx?.targetReps,
      targetDurationSec: targetDurationSec ?? localEx?.targetDurationSec,
      targetDistanceM: targetDistanceM ?? localEx?.targetDistanceM,
      notes: notes ?? localEx?.notes,
    );
  }

  @override
  Future<void> deletePlanExercise({
    required String planId,
    required String planDayExerciseId,
  }) async {
    // ── Delete locally first (offline-first) ─────────────────────────────────
    await _planDao.deletePlanDayExercise(planDayExerciseId);

    // ── Sync to server (best-effort) ─────────────────────────────────────────
    try {
      await _apiClient.deleteExercise(planId, planDayExerciseId);
    } catch (e) {
      debugPrint('WorkoutPlanRepository: deletePlanExercise server sync failed: $e');
      await enqueueSyncItem(
        dao: _syncDao,
        userId: _userId,
        entityTable: 'plan_day_exercises',
        recordId: planDayExerciseId,
        operation: SyncOperation.delete,
        payload: {'planId': planId},
      );
    }
  }

  @override
  Future<void> reorderDayExercises({
    required String planId,
    required String planDayId,
    required List<String> orderedExerciseIds,
  }) async {
    // ── Write locally first (offline-first) ──────────────────────────────────
    await _planDao.reorderPlanDayExercises(planDayId, orderedExerciseIds);

    // ── Sync to server (best-effort) ─────────────────────────────────────────
    try {
      final body = ReorderPlanExercisesRequestDto(
        planDayId: planDayId,
        planDayExerciseIds: orderedExerciseIds,
      );
      await _apiClient.reorderExercises(planId, body);
    } catch (e) {
      debugPrint('WorkoutPlanRepository: reorderDayExercises server sync failed: $e');
      // Enqueue individual sort-order updates for each exercise.
      for (var i = 0; i < orderedExerciseIds.length; i++) {
        await enqueueSyncItem(
          dao: _syncDao,
          userId: _userId,
          entityTable: 'plan_day_exercises',
          recordId: orderedExerciseIds[i],
          operation: SyncOperation.update,
          payload: {'sortOrder': i},
        );
      }
    }
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
