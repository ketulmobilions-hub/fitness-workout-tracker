import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import 'plan_form_state.dart';
import 'workout_plan_providers.dart';

part 'plan_form_provider.g.dart';

/// Multi-step workout plan form notifier.
///
/// [planId] is null for create mode and the plan's UUID for edit mode.
/// Auto-disposed so form state is discarded when the user leaves the screen.
@riverpod
class PlanForm extends _$PlanForm {
  /// Session-scoped counter for generating stable, unique [DraftPlanExercise.localId]
  /// values without requiring an external UUID package.
  static int _localIdCounter = 0;

  static String _nextLocalId() => 'local_${++_localIdCounter}';

  @override
  PlanFormState build(String? planId) {
    if (planId != null) {
      _seedFromExistingPlan(planId);
    }
    return PlanFormState(editingPlanId: planId);
  }

  // ---------------------------------------------------------------------------
  // Seeding (edit mode)
  // ---------------------------------------------------------------------------

  Future<void> _seedFromExistingPlan(String planId) async {
    state = state.copyWith(isSeeding: true);

    // Guard against mutating state after the provider is auto-disposed (e.g.
    // the user navigates back before the Drift query completes).
    var cancelled = false;
    ref.onDispose(() => cancelled = true);

    final plan = await ref
        .read(workoutPlanRepositoryProvider)
        .watchPlan(planId)
        .first;

    if (cancelled) return;

    if (plan == null) {
      state = state.copyWith(isSeeding: false);
      return;
    }

    // Build selectedDays from the existing plan days.
    final selectedDays = plan.days.map((d) => d.dayOfWeek).toSet();

    state = state.copyWith(
      editingPlanId: planId,
      name: plan.name,
      description: plan.description ?? '',
      scheduleType: plan.scheduleType,
      weeksCount: plan.weeksCount ?? 4,
      selectedDays: selectedDays,
      days: plan.days
          .map(
            (d) => DraftPlanDay(
              serverId: d.id,
              dayOfWeek: d.dayOfWeek,
              weekNumber: d.weekNumber,
              name: d.name,
              sortOrder: d.sortOrder,
              exercises: d.exercises
                  .map(
                    (ex) => DraftPlanExercise(
                      // Existing exercises use their server ID as the local ID
                      // so they are stable through reorders.
                      localId: ex.id,
                      serverId: ex.id,
                      exerciseId: ex.exerciseId,
                      exerciseName: ex.exerciseName,
                      exerciseType: ex.exerciseType,
                      sortOrder: ex.sortOrder,
                      targetSets: ex.targetSets,
                      targetReps: ex.targetReps,
                      targetDurationSec: ex.targetDurationSec,
                      targetDistanceM: ex.targetDistanceM,
                      notes: ex.notes,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
      isSeeding: false,
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0 — Details mutations
  // ---------------------------------------------------------------------------

  void setName(String value) {
    state = state.copyWith(
      name: value,
      fieldErrors: Map.of(state.fieldErrors)..remove('name'),
    );
  }

  void setDescription(String value) {
    state = state.copyWith(description: value);
  }

  // ---------------------------------------------------------------------------
  // Step 1 — Schedule mutations
  // ---------------------------------------------------------------------------

  void setScheduleType(ScheduleType type) {
    state = state.copyWith(scheduleType: type, selectedDays: {});
  }

  void setWeeksCount(int count) {
    state = state.copyWith(weeksCount: count);
  }

  void toggleDay(int dayOfWeek) {
    final updated = Set<int>.of(state.selectedDays);
    if (updated.contains(dayOfWeek)) {
      updated.remove(dayOfWeek);
    } else {
      updated.add(dayOfWeek);
    }
    state = state.copyWith(
      selectedDays: updated,
      fieldErrors: Map.of(state.fieldErrors)..remove('days'),
    );
  }

  // ---------------------------------------------------------------------------
  // Step navigation with validation
  // ---------------------------------------------------------------------------

  /// Advances (or retreats) to [step]. Validates the current step before
  /// advancing and blocks with inline errors on failure.
  ///
  /// When advancing to the exercises step would silently drop exercises from
  /// days that no longer exist in the new schedule, this sets
  /// [PlanFormState.pendingScheduleRebuild] instead of advancing immediately.
  /// The UI must show a confirmation dialog and call [confirmScheduleRebuild]
  /// or [cancelScheduleRebuild] in response.
  void goToStep(PlanFormStep step) {
    // Block navigation while seeding from Drift (edit mode only).
    if (state.isSeeding) return;

    // Moving back never requires validation.
    final isAdvancing = step.index > state.currentStep.index;

    if (isAdvancing) {
      if (!_validateCurrentStep()) return;

      if (step == PlanFormStep.exercises) {
        // If the schedule change would silently drop exercises, pause and ask
        // the user to confirm before rebuilding the days list.
        if (_wouldLoseExercises()) {
          state = state.copyWith(pendingScheduleRebuild: true);
          return;
        }
        _buildDraftDays();
      }
    }

    state = state.copyWith(currentStep: step);
  }

  /// Called after the user confirms they are OK losing exercises from days
  /// that no longer fit the new schedule. Rebuilds the days list and advances.
  void confirmScheduleRebuild() {
    state = state.copyWith(pendingScheduleRebuild: false);
    _buildDraftDays();
    state = state.copyWith(currentStep: PlanFormStep.exercises);
  }

  /// Called when the user cancels the schedule-rebuild confirmation dialog.
  void cancelScheduleRebuild() {
    state = state.copyWith(pendingScheduleRebuild: false);
  }

  bool _validateCurrentStep() {
    switch (state.currentStep) {
      case PlanFormStep.details:
        if (state.name.trim().isEmpty) {
          state = state.copyWith(
            fieldErrors: {...state.fieldErrors, 'name': 'Plan name is required'},
          );
          return false;
        }
        return true;

      case PlanFormStep.schedule:
        if (state.selectedDays.isEmpty) {
          state = state.copyWith(
            fieldErrors: {...state.fieldErrors, 'days': 'Select at least one day'},
          );
          return false;
        }
        return true;

      case PlanFormStep.exercises:
        return true;
    }
  }

  /// Returns true if advancing to the exercises step would discard exercises
  /// from days that no longer exist under the current schedule config.
  bool _wouldLoseExercises() {
    if (state.days.every((d) => d.exercises.isEmpty)) return false;

    final expectedKeys = _buildExpectedKeys();
    return state.days.any(
      (d) =>
          d.exercises.isNotEmpty &&
          !expectedKeys.contains((d.dayOfWeek, d.weekNumber)),
    );
  }

  Set<(int, int?)> _buildExpectedKeys() {
    final sortedDays = state.selectedDays.toList()..sort();
    final keys = <(int, int?)>{};
    if (state.scheduleType == ScheduleType.weekly) {
      for (final dow in sortedDays) {
        keys.add((dow, null));
      }
    } else {
      for (var week = 1; week <= state.weeksCount; week++) {
        for (final dow in sortedDays) {
          keys.add((dow, week as int?));
        }
      }
    }
    return keys;
  }

  /// Materialises [DraftPlanDay] entries from the current schedule config.
  ///
  /// Skips rebuilding if the expected (dayOfWeek, weekNumber) keys already
  /// match the current days list — preserving exercises when the user navigates
  /// back to step 1 and forward again without changing the schedule.
  ///
  /// In edit mode, existing days are matched by (dayOfWeek, weekNumber) so
  /// their [serverId] and exercises are preserved.
  void _buildDraftDays() {
    final sortedDays = state.selectedDays.toList()..sort();
    final expectedKeys = _buildExpectedKeys();

    // Build actual key set from the current days.
    final actualKeys = <(int, int?)>{
      for (final d in state.days) (d.dayOfWeek, d.weekNumber),
    };

    // Skip rebuild if schedule config hasn't changed — preserves exercises.
    if (setEquals(expectedKeys, actualKeys)) return;

    final existing = {
      for (final d in state.days) (d.dayOfWeek, d.weekNumber): d,
    };

    final List<DraftPlanDay> built = [];

    if (state.scheduleType == ScheduleType.weekly) {
      for (var i = 0; i < sortedDays.length; i++) {
        final dow = sortedDays[i];
        final key = (dow, null as int?);
        built.add(
          existing[key]?.copyWith(sortOrder: i) ??
              DraftPlanDay(
                dayOfWeek: dow,
                weekNumber: null,
                sortOrder: i,
              ),
        );
      }
    } else {
      // Recurring: one entry per (week, dayOfWeek) combination.
      var sortOrder = 0;
      for (var week = 1; week <= state.weeksCount; week++) {
        for (final dow in sortedDays) {
          final key = (dow, week as int?);
          built.add(
            existing[key]?.copyWith(sortOrder: sortOrder) ??
                DraftPlanDay(
                  dayOfWeek: dow,
                  weekNumber: week,
                  sortOrder: sortOrder,
                ),
          );
          sortOrder++;
        }
      }
    }

    state = state.copyWith(days: built);
  }

  // ---------------------------------------------------------------------------
  // Step 2 — Exercise mutations per day
  // ---------------------------------------------------------------------------

  void addExercises(int dayIndex, List<Exercise> exercises) {
    final day = state.days[dayIndex];
    final base = day.exercises.length;
    final newExercises = [
      ...day.exercises,
      ...exercises.asMap().entries.map(
            (e) => DraftPlanExercise(
              localId: _nextLocalId(),
              exerciseId: e.value.id,
              exerciseName: e.value.name,
              exerciseType: e.value.exerciseType,
              sortOrder: base + e.key,
            ),
          ),
    ];
    _updateDay(dayIndex, day.copyWith(exercises: newExercises));
  }

  void removeExercise(int dayIndex, int exerciseIndex) {
    final day = state.days[dayIndex];
    final exercises = [...day.exercises]..removeAt(exerciseIndex);
    // Re-index sort orders after removal.
    final reindexed = exercises
        .asMap()
        .entries
        .map((e) => e.value.copyWith(sortOrder: e.key))
        .toList();
    _updateDay(dayIndex, day.copyWith(exercises: reindexed));
  }

  void reorderExercises(int dayIndex, int oldIndex, int newIndex) {
    final day = state.days[dayIndex];
    final exercises = [...day.exercises];
    // ReorderableListView passes newIndex > oldIndex with the item still in
    // place — adjust before inserting.
    final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final item = exercises.removeAt(oldIndex);
    exercises.insert(adjusted, item);
    final reindexed = exercises
        .asMap()
        .entries
        .map((e) => e.value.copyWith(sortOrder: e.key))
        .toList();
    _updateDay(dayIndex, day.copyWith(exercises: reindexed));
  }

  /// Updates target fields for the exercise identified by [localId].
  ///
  /// Searches globally across all days so the reference stays valid even if
  /// the exercise was reordered after the targets sheet was opened.
  ///
  /// Passing `null` for any target field **keeps the existing value**. To
  /// explicitly clear a field, pass the corresponding `clear*` flag as true.
  /// This prevents a partial update (e.g. only updating notes) from
  /// accidentally nulling out unrelated fields.
  void updateExerciseTargets({
    required String localId,
    int? targetSets,
    bool clearSets = false,
    String? targetReps,
    bool clearReps = false,
    int? targetDurationSec,
    bool clearDuration = false,
    double? targetDistanceM,
    bool clearDistance = false,
    String? notes,
    bool clearNotes = false,
  }) {
    for (var di = 0; di < state.days.length; di++) {
      final day = state.days[di];
      final ei = day.exercises.indexWhere((ex) => ex.localId == localId);
      if (ei == -1) continue;
      final ex = day.exercises[ei];
      final updated = ex.copyWith(
        targetSets: clearSets ? null : targetSets ?? ex.targetSets,
        targetReps: clearReps ? null : targetReps ?? ex.targetReps,
        targetDurationSec:
            clearDuration ? null : targetDurationSec ?? ex.targetDurationSec,
        targetDistanceM:
            clearDistance ? null : targetDistanceM ?? ex.targetDistanceM,
        notes: clearNotes ? null : notes ?? ex.notes,
      );
      final exercises = [...day.exercises];
      exercises[ei] = updated;
      _updateDay(di, day.copyWith(exercises: exercises));
      return;
    }
  }

  void _updateDay(int dayIndex, DraftPlanDay updated) {
    final days = [...state.days];
    days[dayIndex] = updated;
    state = state.copyWith(days: days);
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> save() async {
    if (state.isSeeding) return;

    // Validate that at least one day has at least one exercise.
    final hasExercises = state.days.any((d) => d.exercises.isNotEmpty);
    if (!hasExercises) {
      state = state.copyWith(
        saveError: const AppException.validation(
          message: 'Add at least one exercise to your plan',
        ),
      );
      return;
    }

    state = state.copyWith(isSaving: true, saveError: null);
    try {
      if (state.editingPlanId == null) {
        await _saveCreate();
      } else {
        await _saveEdit(state.editingPlanId!);
      }
    } on AppException catch (e) {
      state = state.copyWith(isSaving: false, saveError: e);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        saveError: AppException.unknown(message: e.toString()),
      );
    }
  }

  Future<void> _saveCreate() async {
    final repo = ref.read(workoutPlanRepositoryProvider);

    String planId;
    Map<(int, int?), String> dayIdMap;
    // planDayId → exercises already on the server for that day.
    // Populated only in the retry path so the add loop can skip fully-saved
    // days and clean up partially-saved days before re-adding.
    Map<String, List<PlanDayExercise>> serverExercisesByDayId = {};

    if (state.creatingPlanId != null) {
      // Plan was already created on a previous (interrupted) attempt.
      // Re-sync from server to get the latest day/exercise state, then resume.
      planId = state.creatingPlanId!;
      await repo.syncPlanDetail(planId);
      final existing = await repo.watchPlan(planId).first;
      dayIdMap = {
        for (final d in existing?.days ?? <PlanDay>[])
          (d.dayOfWeek, d.weekNumber): d.id,
      };
      serverExercisesByDayId = {
        for (final d in existing?.days ?? <PlanDay>[]) d.id: d.exercises,
      };
    } else {
      // POST /plans — creates the plan with day stubs only (no exercises).
      //
      // PlanDay(id: '') is used as a stub: the domain repository converts these
      // to CreatePlanDayDto objects and the server assigns real UUIDs. The
      // empty string is never persisted to Drift.
      final created = await repo.createPlan(
        name: state.name.trim(),
        description: state.description.trim().isEmpty
            ? null
            : state.description.trim(),
        scheduleType: state.scheduleType,
        weeksCount: state.scheduleType == ScheduleType.recurring
            ? state.weeksCount
            : null,
        initialDays: state.days
            .map(
              (d) => PlanDay(
                id: '',
                dayOfWeek: d.dayOfWeek,
                weekNumber: d.weekNumber,
                name: d.name,
                sortOrder: d.sortOrder,
              ),
            )
            .toList(),
      );
      planId = created.id;
      dayIdMap = {
        for (final d in created.days) (d.dayOfWeek, d.weekNumber): d.id,
      };
      // Persist the plan ID before adding exercises so a retry can resume.
      state = state.copyWith(creatingPlanId: planId);
    }

    // Add exercises across all days — parallelise within each day, sequential
    // across days to avoid overwhelming the server.
    for (final draftDay in state.days) {
      final planDayId = dayIdMap[(draftDay.dayOfWeek, draftDay.weekNumber)];
      if (planDayId == null) continue;
      if (draftDay.exercises.isEmpty) continue;

      final serverExercises = serverExercisesByDayId[planDayId] ?? [];

      // On retry, delete any exercises already on the server for this day
      // before re-adding the full draft. Count-matching is not used as a
      // skip condition because the user may have modified the draft (reorder,
      // target change, exercise swap) between the interrupted attempt and the
      // retry — skipping on count alone would silently save stale data.
      if (serverExercises.isNotEmpty) {
        await Future.wait([
          for (final ex in serverExercises)
            repo.deletePlanExercise(planId: planId, planDayExerciseId: ex.id),
        ]);
      }

      await Future.wait([
        for (var i = 0; i < draftDay.exercises.length; i++)
          repo.addExerciseToDay(
            planId: planId,
            planDayId: planDayId,
            exerciseId: draftDay.exercises[i].exerciseId,
            sortOrder: i,
            targetSets: draftDay.exercises[i].targetSets,
            targetReps: draftDay.exercises[i].targetReps,
            targetDurationSec: draftDay.exercises[i].targetDurationSec,
            targetDistanceM: draftDay.exercises[i].targetDistanceM,
            notes: draftDay.exercises[i].notes,
          ),
      ]);
    }

    // Refresh the local cache with the full plan (exercises populated).
    await repo.syncPlanDetail(planId);

    state = state.copyWith(
      isSaving: false,
      saved: true,
      savedPlanId: planId,
    );
  }

  Future<void> _saveEdit(String planId) async {
    final repo = ref.read(workoutPlanRepositoryProvider);

    // One-shot read of the current server-synced plan for diffing.
    final original = await repo.watchPlan(planId).first;

    if (original == null) {
      throw const AppException.serverError(
        statusCode: 404,
        message: 'Plan not found. It may have been deleted.',
      );
    }

    // 1. Update plan metadata if anything changed.
    final nameChanged = state.name.trim() != original.name;
    final descChanged =
        state.description.trim() != (original.description?.trim() ?? '');
    final typeChanged = state.scheduleType != original.scheduleType;
    final weeksChanged = state.scheduleType == ScheduleType.recurring &&
        state.weeksCount != (original.weeksCount ?? 4);

    if (nameChanged || descChanged || typeChanged || weeksChanged) {
      await repo.updatePlan(
        id: planId,
        name: nameChanged ? state.name.trim() : null,
        description: descChanged
            ? (state.description.trim().isEmpty
                ? null
                : state.description.trim())
            : null,
        scheduleType: typeChanged ? state.scheduleType : null,
        weeksCount: weeksChanged ? state.weeksCount : null,
      );
    }

    // 2. Compute which server exercise IDs have been removed.
    final originalExIds = {
      for (final d in original.days)
        for (final ex in d.exercises) ex.id,
    };
    final draftExServerIds = {
      for (final d in state.days)
        for (final ex in d.exercises)
          if (ex.serverId != null) ex.serverId!,
    };

    // Build a map for quick original exercise lookup: serverId → PlanDayExercise.
    final originalExMap = {
      for (final d in original.days)
        for (final ex in d.exercises) ex.id: ex,
    };

    // Delete removed exercises.
    await Future.wait([
      for (final exId in originalExIds)
        if (!draftExServerIds.contains(exId))
          repo.deletePlanExercise(planId: planId, planDayExerciseId: exId),
    ]);

    // Build a map of original days keyed by server ID.
    final originalDayMap = {
      for (final d in original.days) d.id: d,
    };

    // 3. Process each draft day: add new exercises, update changed targets,
    //    and reorder if the exercise order differs from the original.
    for (final draftDay in state.days) {
      // Resolve the server planDayId for this draft day.
      final planDayId = draftDay.serverId ??
          original.days
              .where(
                (d) =>
                    d.dayOfWeek == draftDay.dayOfWeek &&
                    d.weekNumber == draftDay.weekNumber,
              )
              .firstOrNull
              ?.id;

      if (planDayId == null) continue;

      final originalDay = originalDayMap[planDayId];

      // "New" exercises: no serverId, OR serverId not found in originalExMap
      // (orphaned from a prior partial edit). Both cases require an add call.
      final newExercises = draftDay.exercises
          .where(
            (ex) =>
                ex.serverId == null ||
                !originalExMap.containsKey(ex.serverId),
          )
          .toList();

      // Maps localId → server-assigned exercise ID for exercises added in
      // this save operation (needed to build the full reorder list below).
      final addedServerIds = <String, String>{};

      if (newExercises.isNotEmpty) {
        final addResults = await Future.wait(
          newExercises.map(
            (ex) => repo.addExerciseToDay(
              planId: planId,
              planDayId: planDayId,
              exerciseId: ex.exerciseId,
              sortOrder: ex.sortOrder,
              targetSets: ex.targetSets,
              targetReps: ex.targetReps,
              targetDurationSec: ex.targetDurationSec,
              targetDistanceM: ex.targetDistanceM,
              notes: ex.notes,
            ),
          ),
        );
        for (var i = 0; i < newExercises.length; i++) {
          addedServerIds[newExercises[i].localId] = addResults[i].id;
        }
      }

      // Update targets for confirmed-existing exercises (serverId in originalExMap)
      // whose targets differ from the original.
      await Future.wait([
        for (final ex in draftDay.exercises)
          if (ex.serverId != null && originalExMap.containsKey(ex.serverId))
            if (_targetsChanged(ex, originalExMap[ex.serverId]))
              repo.updatePlanExercise(
                planId: planId,
                planDayExerciseId: ex.serverId!,
                targetSets: ex.targetSets,
                targetReps: ex.targetReps,
                targetDurationSec: ex.targetDurationSec,
                targetDistanceM: ex.targetDistanceM,
                notes: ex.notes,
              ),
      ]);

      // Build the complete ordered list (known-original + newly added/re-added)
      // and reorder if it differs from the original.
      final orderedIds = draftDay.exercises
          .map((ex) {
            // Use existing serverId only if it's confirmed in the original.
            if (ex.serverId != null && originalExMap.containsKey(ex.serverId)) {
              return ex.serverId!;
            }
            return addedServerIds[ex.localId];
          })
          .whereType<String>()
          .toList();

      final originalOrder =
          originalDay?.exercises.map((e) => e.id).toList() ?? [];

      if (orderedIds.isNotEmpty && !listEquals(orderedIds, originalOrder)) {
        await repo.reorderDayExercises(
          planId: planId,
          planDayId: planDayId,
          orderedExerciseIds: orderedIds,
        );
      }
    }

    // Refresh the local cache.
    await repo.syncPlanDetail(planId);

    state = state.copyWith(
      isSaving: false,
      saved: true,
      savedPlanId: planId,
    );
  }

  /// Returns true if any target field on [draft] differs from [original].
  bool _targetsChanged(DraftPlanExercise draft, PlanDayExercise? original) {
    if (original == null) return false;
    return draft.targetSets != original.targetSets ||
        draft.targetReps != original.targetReps ||
        draft.targetDurationSec != original.targetDurationSec ||
        draft.targetDistanceM != original.targetDistanceM ||
        draft.notes != original.notes;
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  Future<void> deletePlan() async {
    final planId = state.editingPlanId;
    if (planId == null) return;

    state = state.copyWith(isSaving: true, saveError: null);
    try {
      await ref.read(workoutPlanRepositoryProvider).deletePlan(planId);
      // saved = true with savedPlanId = null signals "navigate to list".
      state = state.copyWith(isSaving: false, saved: true, savedPlanId: null);
    } on AppException catch (e) {
      state = state.copyWith(isSaving: false, saveError: e);
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        saveError: AppException.unknown(message: e.toString()),
      );
    }
  }
}
