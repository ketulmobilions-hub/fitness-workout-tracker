import 'package:freezed_annotation/freezed_annotation.dart';

part 'competition.freezed.dart';

enum CompetitionStatus { upcoming, completed }

enum LiftType { squat, bench, deadlift }

enum AttemptResult { goodLift, noLift, notTaken }

@freezed
abstract class CompetitionAttempt with _$CompetitionAttempt {
  // ignore: unused_element
  const CompetitionAttempt._();
  const factory CompetitionAttempt({
    required String id,
    required LiftType liftType,
    required int attemptNumber,
    required double weightKg,
    required AttemptResult result,
  }) = _CompetitionAttempt;
}

@freezed
abstract class Competition with _$Competition {
  const Competition._();

  const factory Competition({
    required String id,
    required String name,
    String? federation,
    required DateTime date,
    String? location,
    double? weightClassKg,
    double? bodyweightKg,
    String? division,
    required CompetitionStatus status,
    @Default([]) List<CompetitionAttempt> attempts,
    double? squat,
    double? bench,
    double? deadlift,
    double? total,
    double? wilks,
    double? dots,
    double? ipfGl,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _Competition;

  bool get isUpcoming => status == CompetitionStatus.upcoming;
}

abstract class CompetitionRepository {
  Future<List<Competition>> fetchAll();
  Future<Competition> fetchOne(String id);
  Future<Competition> create({
    required String name,
    String? federation,
    required String date,
    String? location,
    double? weightClassKg,
    double? bodyweightKg,
    String? division,
  });
  Future<Competition> logAttempt({
    required String competitionId,
    required String liftType,
    required int attemptNumber,
    required double weightKg,
    required String result,
  });
  Future<void> updateStatus(String competitionId, String status);
}
