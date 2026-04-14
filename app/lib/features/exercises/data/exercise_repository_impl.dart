import 'package:drift/drift.dart' show Value;
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';

class ExerciseRepositoryImpl implements ExerciseRepository {
  ExerciseRepositoryImpl({
    required ExerciseApiClient apiClient,
    required ExerciseDao exerciseDao,
  })  : _apiClient = apiClient,
        _exerciseDao = exerciseDao;

  final ExerciseApiClient _apiClient;
  final ExerciseDao _exerciseDao;

  // ---------------------------------------------------------------------------
  // Read — streams from local Drift DB (offline-first)
  // ---------------------------------------------------------------------------

  @override
  Stream<List<Exercise>> watchExercises({
    String? search,
    ExerciseType? type,
    String? muscleGroupName,
  }) {
    return _exerciseDao
        .watchExercisesFiltered(
          search: search,
          type: type,
          muscleGroupName: muscleGroupName,
        )
        .map((rows) => rows.map(_rowToExercise).toList());
  }

  @override
  Stream<Exercise?> watchExercise(String id) {
    // Use asyncMap + a Future-based muscle group lookup (not .first on a
    // broadcast stream, which waits for the NEXT write rather than the current
    // value). getExerciseMuscleGroupsWithPrimary executes a one-shot SQL query
    // each time the exercise row changes, giving a consistent snapshot.
    return _exerciseDao.watchExercise(id).asyncMap((row) async {
      if (row == null) return null;
      final mgPairs =
          await _exerciseDao.getExerciseMuscleGroupsWithPrimary(id);
      return _buildExercise(row, mgPairs);
    });
  }

  @override
  Stream<List<MuscleGroup>> watchMuscleGroups() {
    return _exerciseDao.watchAllMuscleGroupsStream().map(
          (rows) => rows
              .map(
                (r) => MuscleGroup(
                  id: r.id,
                  name: r.name,
                  displayName: r.displayName,
                  bodyRegion: r.bodyRegion,
                ),
              )
              .toList(),
        );
  }

  // ---------------------------------------------------------------------------
  // Sync — API → Drift (C-3: all writes in one transaction)
  // ---------------------------------------------------------------------------

  @override
  Future<void> syncExercises() async {
    // Phase 1: Network — collect all data without touching the DB.
    // This keeps the transaction short and avoids holding a DB lock during
    // potentially-slow network calls.
    final mgResponse = await _apiClient.getMuscleGroups();

    final allExercises = <ExerciseDto>[];
    String? cursor;
    do {
      final response = await _apiClient.listExercises(
        cursor: cursor,
        limit: 100,
      );
      allExercises.addAll(response.data.exercises);
      // m-4: guard against empty-string cursor causing an infinite loop.
      final nextCursor = response.data.pagination.nextCursor;
      cursor = (response.data.pagination.hasMore &&
              nextCursor != null &&
              nextCursor.isNotEmpty)
          ? nextCursor
          : null;
    } while (cursor != null);

    // Phase 2: DB — write everything atomically. If the app is killed mid-way,
    // no partial state is persisted; the next sync starts fresh.
    await _exerciseDao.transaction(() async {
      // Upsert muscle groups.
      for (final mg in mgResponse.data.muscleGroups) {
        await _exerciseDao.upsertMuscleGroup(
          MuscleGroupsCompanion(
            id: Value(mg.id),
            name: Value(mg.name),
            displayName: Value(mg.displayName),
            bodyRegion: Value(mg.bodyRegion),
          ),
        );
      }

      // Upsert exercises and their muscle-group associations.
      final apiIds = <String>{};
      for (final dto in allExercises) {
        apiIds.add(dto.id);
        await _exerciseDao.upsertExercise(_dtoToCompanion(dto));
        await _exerciseDao.setExerciseMuscleGroups(
          dto.id,
          dto.muscleGroups
              .map(
                (mg) => ExerciseMuscleGroupsCompanion(
                  exerciseId: Value(dto.id),
                  muscleGroupId: Value(mg.id),
                  isPrimary: Value(mg.isPrimary),
                ),
              )
              .toList(),
        );
      }

      // C-4: Clean up system exercises that no longer exist on the server.
      // This handles the case where the app crashed after a successful API
      // delete but before the local delete completed.
      await _exerciseDao.deleteSystemExercisesNotInSet(apiIds);
    });
  }

  // ---------------------------------------------------------------------------
  // Muscle groups
  // ---------------------------------------------------------------------------

  @override
  Future<List<MuscleGroup>> getMuscleGroups() async {
    final rows = await _exerciseDao.getAllMuscleGroups();
    return rows
        .map(
          (r) => MuscleGroup(
            id: r.id,
            name: r.name,
            displayName: r.displayName,
            bodyRegion: r.bodyRegion,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Custom exercise CRUD
  // ---------------------------------------------------------------------------

  @override
  Future<Exercise> createCustomExercise({
    required String name,
    String? description,
    required ExerciseType exerciseType,
    String? instructions,
    String? mediaUrl,
    required List<({String muscleGroupId, bool isPrimary})> muscleGroups,
  }) async {
    final envelope = await _apiClient.createExercise(
      CreateExerciseRequestDto(
        name: name,
        description: description,
        exerciseType: const ExerciseTypeConverter().toSql(exerciseType),
        instructions: instructions,
        mediaUrl: mediaUrl,
        muscleGroups: muscleGroups
            .map(
              (mg) => MuscleGroupReferenceDto(
                muscleGroupId: mg.muscleGroupId,
                isPrimary: mg.isPrimary,
              ),
            )
            .toList(),
      ),
    );

    final dto = envelope.data.exercise;
    await _exerciseDao.upsertExercise(_dtoToCompanion(dto));
    await _exerciseDao.setExerciseMuscleGroups(
      dto.id,
      dto.muscleGroups
          .map(
            (mg) => ExerciseMuscleGroupsCompanion(
              exerciseId: Value(dto.id),
              muscleGroupId: Value(mg.id),
              isPrimary: Value(mg.isPrimary),
            ),
          )
          .toList(),
    );

    return _dtoToExercise(dto);
  }

  @override
  Future<void> deleteCustomExercise(String id) async {
    // Delete on server first (authoritative). If the API call fails the local
    // row is preserved. If the app crashes after the API call but before the
    // local delete, the next syncExercises() will clean up the orphaned row via
    // deleteSystemExercisesNotInSet (for system exercises). Custom exercises
    // that become orphaned remain visible in the UI until the user retries.
    await _apiClient.deleteExercise(id);
    await _exerciseDao.deleteExercise(id);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Exercise _buildExercise(
    ExerciseRow row,
    List<({MuscleGroupRow muscleGroup, bool isPrimary})> muscleGroupPairs,
  ) {
    return _rowToExercise(row).copyWith(
      muscleGroups: muscleGroupPairs
          .map(
            (pair) => MuscleGroup(
              id: pair.muscleGroup.id,
              name: pair.muscleGroup.name,
              displayName: pair.muscleGroup.displayName,
              bodyRegion: pair.muscleGroup.bodyRegion,
              isPrimary: pair.isPrimary,
            ),
          )
          .toList(),
    );
  }

  Exercise _rowToExercise(ExerciseRow row) {
    return Exercise(
      id: row.id,
      name: row.name,
      description: row.description,
      exerciseType: row.exerciseType,
      instructions: row.instructions,
      mediaUrl: row.mediaUrl,
      isCustom: row.isCustom,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  Exercise _dtoToExercise(ExerciseDto dto) {
    return Exercise(
      id: dto.id,
      name: dto.name,
      description: dto.description,
      exerciseType: const ExerciseTypeConverter().fromSql(dto.exerciseType),
      instructions: dto.instructions,
      mediaUrl: dto.mediaUrl,
      isCustom: dto.isCustom,
      createdAt: dto.createdAt,
      updatedAt: dto.updatedAt,
      muscleGroups: dto.muscleGroups
          .map(
            (mg) => MuscleGroup(
              id: mg.id,
              name: mg.name,
              displayName: mg.displayName,
              bodyRegion: mg.bodyRegion,
              isPrimary: mg.isPrimary,
            ),
          )
          .toList(),
    );
  }

  ExercisesCompanion _dtoToCompanion(ExerciseDto dto) {
    return ExercisesCompanion(
      id: Value(dto.id),
      name: Value(dto.name),
      description: Value(dto.description),
      exerciseType:
          Value(const ExerciseTypeConverter().fromSql(dto.exerciseType)),
      instructions: Value(dto.instructions),
      mediaUrl: Value(dto.mediaUrl),
      isCustom: Value(dto.isCustom),
      createdAt: Value(dto.createdAt),
      updatedAt: Value(dto.updatedAt),
    );
  }
}
