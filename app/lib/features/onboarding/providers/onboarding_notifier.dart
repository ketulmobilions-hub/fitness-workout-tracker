import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/errors/app_exception_mapper.dart';
import '../../../features/profile/providers/profile_providers.dart';
import 'first_launch_provider.dart';

part 'onboarding_notifier.freezed.dart';
part 'onboarding_notifier.g.dart';

enum ExperienceLevel {
  beginner,
  intermediate,
  advanced;

  String get label => switch (this) {
        ExperienceLevel.beginner => 'Beginner (< 1 year)',
        ExperienceLevel.intermediate => 'Intermediate (1–3 years)',
        ExperienceLevel.advanced => 'Advanced (3+ years)',
      };

  String get description => switch (this) {
        ExperienceLevel.beginner =>
          'New to the sport or still learning the competition lifts',
        ExperienceLevel.intermediate =>
          'Competed before, consistent progress on the platform',
        ExperienceLevel.advanced =>
          'Experienced competitor chasing elite totals and meet PRs',
      };

  String get suggestion => switch (this) {
        ExperienceLevel.beginner =>
          'Starting Strength or GZCLP — build technique and consistency before worrying about percentages.',
        ExperienceLevel.intermediate =>
          '5/3/1 or Juggernaut Method — linear progression still works but you need planned variation.',
        ExperienceLevel.advanced =>
          'Sheiko or Block Periodization — high specificity and planned peaks aligned to your meet schedule.',
      };
}

@freezed
abstract class OnboardingDraft with _$OnboardingDraft {
  const factory OnboardingDraft({
    ExperienceLevel? experienceLevel,
    String? federation,
    String? gender,
    String? division,
    double? weightClassKg,
    double? squatKg,
    double? benchKg,
    double? deadliftKg,
    @Default(false) bool isSubmitting,
    AppException? error,
  }) = _OnboardingDraft;
}

@Riverpod(keepAlive: true)
class OnboardingNotifier extends _$OnboardingNotifier {
  @override
  OnboardingDraft build() => const OnboardingDraft();

  void setExperienceLevel(ExperienceLevel level) =>
      state = state.copyWith(experienceLevel: level, error: null);

  void setFederation(String? v) => state = state.copyWith(
        federation: (v?.isEmpty ?? true) ? null : v,
        weightClassKg: null,
        error: null,
      );

  void setGender(String? v) => state = state.copyWith(
        gender: v,
        weightClassKg: null,
        error: null,
      );

  void setDivision(String? v) => state = state.copyWith(
        division: (v?.isEmpty ?? true) ? null : v,
        error: null,
      );

  void setWeightClass(double? v) =>
      state = state.copyWith(weightClassKg: v, error: null);

  void setSquat(double? v) => state = state.copyWith(squatKg: v, error: null);
  void setBench(double? v) => state = state.copyWith(benchKg: v, error: null);
  void setDeadlift(double? v) =>
      state = state.copyWith(deadliftKg: v, error: null);

  Future<bool> submit() async {
    state = state.copyWith(isSubmitting: true, error: null);
    try {
      final hasCompetitionData = state.federation != null ||
          state.division != null ||
          state.weightClassKg != null ||
          state.gender != null;

      if (hasCompetitionData) {
        await ref.read(profileRepositoryProvider).updateCompetitionProfile(
              federation: state.federation,
              division: state.division,
              weightClassKg: state.weightClassKg,
              gender: state.gender,
            );
      }
      await ref.read(onboardingCompleteProvider.notifier).markComplete();
      return true;
    } catch (e) {
      state = state.copyWith(error: mapToAppException(e));
      return false;
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }

  void reset() => state = const OnboardingDraft();
}
