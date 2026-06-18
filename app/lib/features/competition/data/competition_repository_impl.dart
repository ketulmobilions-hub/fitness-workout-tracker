import 'package:dio/dio.dart';
import 'package:fitness_data/fitness_data.dart';
import 'package:fitness_domain/fitness_domain.dart';

class CompetitionRepositoryImpl implements CompetitionRepository {
  CompetitionRepositoryImpl({required CompetitionApiClient apiClient})
      : _apiClient = apiClient;

  final CompetitionApiClient _apiClient;

  Never _mapError(Object e) {
    if (e is DioException) {
      if (e.response?.statusCode == 401) {
        throw Exception('Your session has expired. Please log in again.');
      }
      if (e.response?.statusCode == 404) {
        throw Exception('Competition not found.');
      }
      throw Exception('Network error: ${e.message ?? e.type.name}');
    }
    throw Exception('Unexpected error: $e');
  }

  Competition _mapDto(CompetitionDto dto) {
    return Competition(
      id: dto.id,
      name: dto.name,
      federation: dto.federation,
      date: DateTime.parse(dto.date),
      location: dto.location,
      weightClassKg: dto.weightClassKg,
      bodyweightKg: dto.bodyweightKg,
      division: dto.division,
      status: dto.status == 'upcoming'
          ? CompetitionStatus.upcoming
          : CompetitionStatus.completed,
      attempts: dto.attempts.map(_mapAttemptDto).toList(),
      squat: dto.squat,
      bench: dto.bench,
      deadlift: dto.deadlift,
      total: dto.total,
      wilks: dto.wilks,
      dots: dto.dots,
      ipfGl: dto.ipfGl,
      createdAt: DateTime.parse(dto.createdAt),
      updatedAt: DateTime.parse(dto.updatedAt),
    );
  }

  CompetitionAttempt _mapAttemptDto(CompetitionAttemptDto dto) {
    return CompetitionAttempt(
      id: dto.id,
      liftType: _parseLiftType(dto.liftType),
      attemptNumber: dto.attemptNumber,
      weightKg: dto.weightKg,
      result: _parseResult(dto.result),
    );
  }

  LiftType _parseLiftType(String s) => switch (s) {
        'squat' => LiftType.squat,
        'bench' => LiftType.bench,
        'deadlift' => LiftType.deadlift,
        _ => throw StateError('Unknown lift type: $s'),
      };

  AttemptResult _parseResult(String s) => switch (s) {
        'good_lift' => AttemptResult.goodLift,
        'no_lift' => AttemptResult.noLift,
        'not_taken' => AttemptResult.notTaken,
        _ => throw StateError('Unknown result: $s'),
      };

  @override
  Future<List<Competition>> fetchAll() async {
    try {
      final envelope = await _apiClient.listCompetitions();
      return envelope.data.map(_mapDto).toList();
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<Competition> fetchOne(String id) async {
    try {
      final envelope = await _apiClient.getCompetition(id);
      return _mapDto(envelope.data);
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<Competition> create({
    required String name,
    String? federation,
    required String date,
    String? location,
    double? weightClassKg,
    double? bodyweightKg,
    String? division,
  }) async {
    try {
      final envelope = await _apiClient.createCompetition({
        'name': name,
        if (federation != null) 'federation': federation,
        'date': date,
        if (location != null) 'location': location,
        if (weightClassKg != null) 'weightClassKg': weightClassKg,
        if (bodyweightKg != null) 'bodyweightKg': bodyweightKg,
        if (division != null) 'division': division,
      });
      return _mapDto(envelope.data);
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<Competition> logAttempt({
    required String competitionId,
    required String liftType,
    required int attemptNumber,
    required double weightKg,
    required String result,
  }) async {
    try {
      await _apiClient.logAttempt(competitionId, {
        'liftType': liftType,
        'attemptNumber': attemptNumber,
        'weightKg': weightKg,
        'result': result,
      });
      // Re-fetch the full competition so the caller gets updated totals/scores.
      final envelope = await _apiClient.getCompetition(competitionId);
      return _mapDto(envelope.data);
    } catch (e) {
      _mapError(e);
    }
  }

  @override
  Future<void> updateStatus(String competitionId, String status) async {
    try {
      await _apiClient.updateCompetition(competitionId, {'status': status});
    } catch (e) {
      _mapError(e);
    }
  }
}
