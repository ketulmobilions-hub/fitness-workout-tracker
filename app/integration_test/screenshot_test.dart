// ignore_for_file: avoid_print

import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:ironlog/core/theme/app_theme.dart';
import 'package:ironlog/features/active_session/presentation/screens/active_workout_screen.dart';
import 'package:ironlog/features/active_session/providers/active_session_notifier.dart';
import 'package:ironlog/features/competition/presentation/screens/meet_day_screen.dart';
import 'package:ironlog/features/competition/providers/competition_providers.dart';
import 'package:ironlog/features/pr_share/models/pr_card_data.dart';
import 'package:ironlog/features/pr_share/widgets/pr_card.dart';
import 'package:ironlog/features/progress/presentation/screens/progress_dashboard_screen.dart';
import 'package:ironlog/features/progress/providers/progress_providers.dart';
import 'package:ironlog/features/workout_plans/presentation/screens/plan_detail_screen.dart';
import 'package:ironlog/features/workout_plans/providers/plan_detail_provider.dart';
import 'package:ironlog/features/profile/providers/profile_providers.dart';

// ---------------------------------------------------------------------------
// Fixed timestamp so mock data is stable across the full suite run.
// ---------------------------------------------------------------------------

final _anchor = DateTime(2026, 6, 22, 10, 30);

// ---------------------------------------------------------------------------
// Mock data
// ---------------------------------------------------------------------------

final _mockProfile = UserProfile(
  id: 'u1',
  displayName: 'Alex Thompson',
  federation: 'IPF',
  division: 'Open',
  weightClassKg: 93.0,
  bodyweightKg: 91.2,
  gender: 'M',
  authProvider: UserAuthProvider.emailPassword,
  isGuest: false,
  preferences: const UserPreferences(scoreSystem: ScoreSystem.dots),
  createdAt: DateTime(2025, 1, 1),
  updatedAt: _anchor,
);

final _mockSessionState = ActiveSessionState(
  session: WorkoutSession(
    id: 's1',
    userId: 'u1',
    startedAt: _anchor.subtract(const Duration(minutes: 47)),
    status: SessionStatus.inProgress,
    createdAt: _anchor.subtract(const Duration(minutes: 47)),
    updatedAt: _anchor,
  ),
  exerciseData: [
    ActiveExerciseData(
      planExercise: const PlanDayExercise(
        id: 'pe1',
        exerciseId: 'e1',
        exerciseName: 'Back Squat',
        exerciseType: ExerciseType.strength,
        sortOrder: 0,
        targetSets: 5,
        targetReps: '3',
        targetRpe: 8.5,
      ),
      loggedSets: [
        SetLog(
          id: 'sl1', exerciseLogId: 'el1', setNumber: 1,
          weightKg: 175.0, reps: 3, rpe: 7.5,
          completedAt: _anchor.subtract(const Duration(minutes: 30)),
        ),
        SetLog(
          id: 'sl2', exerciseLogId: 'el1', setNumber: 2,
          weightKg: 180.0, reps: 3, rpe: 8.0,
          completedAt: _anchor.subtract(const Duration(minutes: 20)),
        ),
        SetLog(
          id: 'sl3', exerciseLogId: 'el1', setNumber: 3,
          weightKg: 182.5, reps: 3, rpe: 8.5,
          completedAt: _anchor.subtract(const Duration(minutes: 8)),
        ),
      ],
    ),
    ActiveExerciseData(
      planExercise: const PlanDayExercise(
        id: 'pe2',
        exerciseId: 'e2',
        exerciseName: 'Competition Bench Press',
        exerciseType: ExerciseType.strength,
        sortOrder: 1,
        targetSets: 4,
        targetReps: '5',
        targetRpe: 8.0,
      ),
    ),
    ActiveExerciseData(
      planExercise: const PlanDayExercise(
        id: 'pe3',
        exerciseId: 'e3',
        exerciseName: 'Deadlift',
        exerciseType: ExerciseType.strength,
        sortOrder: 2,
        targetSets: 3,
        targetReps: '3',
        targetRpe: 9.0,
      ),
    ),
  ],
  currentExerciseIndex: 0,
);

const _mockOverview = ProgressOverview(
  totalWorkouts: 147,
  volumeThisWeek: 12450.0,
  volumeThisMonth: 48200.0,
  currentStreak: 12,
  longestStreak: 28,
  lastWorkoutDate: '2026-06-22',
  wilks: 298.6,
  dots: 312.4,
  ipfGl: 89.3,
);

final _mockPRs = [
  const ProgressPersonalRecord(
    id: 'pr1', exerciseId: 'e1', exerciseName: 'Back Squat',
    recordType: 'max_weight', value: 182.5, achievedAt: '2026-06-22',
  ),
  const ProgressPersonalRecord(
    id: 'pr2', exerciseId: 'e2', exerciseName: 'Competition Bench Press',
    recordType: 'max_weight', value: 115.0, achievedAt: '2026-05-18',
  ),
  const ProgressPersonalRecord(
    id: 'pr3', exerciseId: 'e3', exerciseName: 'Deadlift',
    recordType: 'max_weight', value: 227.5, achievedAt: '2026-04-30',
  ),
  const ProgressPersonalRecord(
    id: 'pr4', exerciseId: 'e1', exerciseName: 'Back Squat',
    recordType: 'max_volume', value: 2737.5, achievedAt: '2026-06-08',
  ),
];

const _mockSbdTotal = SbdTotal(
  squat: 182.5,
  bench: 115.0,
  deadlift: 227.5,
  total: 525.0,
  liftCount: 3,
  monthOverMonthDelta: 10.0,
  deltaVsMonth: '2026-05',
  monthly: [
    SbdMonthPoint(month: '2026-01', squat: 160.0, bench: 105.0, deadlift: 210.0),
    SbdMonthPoint(month: '2026-02', squat: 165.0, bench: 107.5, deadlift: 215.0),
    SbdMonthPoint(month: '2026-03', squat: 170.0, bench: 110.0, deadlift: 217.5),
    SbdMonthPoint(month: '2026-04', squat: 175.0, bench: 112.5, deadlift: 220.0),
    SbdMonthPoint(month: '2026-05', squat: 177.5, bench: 112.5, deadlift: 225.0),
    SbdMonthPoint(month: '2026-06', squat: 182.5, bench: 115.0, deadlift: 227.5),
  ],
);

WorkoutPlan _buildMockPlan() => WorkoutPlan(
  id: 'plan1',
  name: '5/3/1 BBB – 4 Week Block',
  description: '4 weeks, 4 days/week. Boring But Big accessory work.',
  isActive: true,
  scheduleType: ScheduleType.recurring,
  weeksCount: 4,
  createdAt: DateTime(2026, 5, 1),
  updatedAt: _anchor,
  days: [
    for (int week = 1; week <= 4; week++) ...[
      PlanDay(
        id: 'day${week}1', dayOfWeek: 1, weekNumber: week,
        name: 'Squat Day', sortOrder: (week - 1) * 3,
        isDeload: week == 4,
        exercises: [
          PlanDayExercise(
            id: 'pe${week}1', exerciseId: 'e1', exerciseName: 'Back Squat',
            exerciseType: ExerciseType.strength, sortOrder: 0,
            targetSets: 3,
            targetReps: week == 1 ? '5' : week == 2 ? '3' : week == 3 ? '1+' : '5',
            targetWeightPct1rm: week == 1 ? 0.65 : week == 2 ? 0.75 : week == 3 ? 0.85 : 0.40,
          ),
        ],
      ),
      PlanDay(
        id: 'day${week}2', dayOfWeek: 3, weekNumber: week,
        name: 'Bench Day', sortOrder: (week - 1) * 3 + 1,
        isDeload: week == 4,
        exercises: [
          PlanDayExercise(
            id: 'pe${week}2', exerciseId: 'e2', exerciseName: 'Competition Bench Press',
            exerciseType: ExerciseType.strength, sortOrder: 0,
            targetSets: 3,
            targetReps: week == 1 ? '5' : week == 2 ? '3' : week == 3 ? '1+' : '5',
            targetWeightPct1rm: week == 1 ? 0.65 : week == 2 ? 0.75 : week == 3 ? 0.85 : 0.40,
          ),
        ],
      ),
      PlanDay(
        id: 'day${week}3', dayOfWeek: 5, weekNumber: week,
        name: 'Deadlift Day', sortOrder: (week - 1) * 3 + 2,
        isDeload: week == 4,
        exercises: [
          PlanDayExercise(
            id: 'pe${week}3', exerciseId: 'e3', exerciseName: 'Deadlift',
            exerciseType: ExerciseType.strength, sortOrder: 0,
            targetSets: 3,
            targetReps: week == 1 ? '5' : week == 2 ? '3' : week == 3 ? '1+' : '5',
            targetWeightPct1rm: week == 1 ? 0.65 : week == 2 ? 0.75 : week == 3 ? 0.85 : 0.40,
          ),
        ],
      ),
    ],
  ],
);

Competition _buildMockMeet() => Competition(
  id: 'c1',
  name: 'IPF World Classic Championships',
  federation: 'IPF',
  date: DateTime(2026, 6, 22),
  location: 'Helsinki, Finland',
  weightClassKg: 93.0,
  bodyweightKg: 91.2,
  division: 'Open',
  status: CompetitionStatus.upcoming,
  createdAt: _anchor,
  updatedAt: _anchor,
  attempts: const [
    CompetitionAttempt(id: 'a1', liftType: LiftType.squat, attemptNumber: 1, weightKg: 180.0, result: AttemptResult.goodLift),
    CompetitionAttempt(id: 'a2', liftType: LiftType.squat, attemptNumber: 2, weightKg: 187.5, result: AttemptResult.goodLift),
    CompetitionAttempt(id: 'a3', liftType: LiftType.squat, attemptNumber: 3, weightKg: 192.5, result: AttemptResult.notTaken),
    CompetitionAttempt(id: 'a4', liftType: LiftType.bench, attemptNumber: 1, weightKg: 110.0, result: AttemptResult.notTaken),
    CompetitionAttempt(id: 'a5', liftType: LiftType.bench, attemptNumber: 2, weightKg: 115.0, result: AttemptResult.notTaken),
    CompetitionAttempt(id: 'a6', liftType: LiftType.bench, attemptNumber: 3, weightKg: 117.5, result: AttemptResult.notTaken),
    CompetitionAttempt(id: 'a7', liftType: LiftType.deadlift, attemptNumber: 1, weightKg: 222.5, result: AttemptResult.notTaken),
    CompetitionAttempt(id: 'a8', liftType: LiftType.deadlift, attemptNumber: 2, weightKg: 230.0, result: AttemptResult.notTaken),
    CompetitionAttempt(id: 'a9', liftType: LiftType.deadlift, attemptNumber: 3, weightKg: 235.0, result: AttemptResult.notTaken),
  ],
);

final _mockPrCardData = PrCardData(
  exerciseName: 'Back Squat',
  recordType: 'max_weight',
  value: 182.5,
  achievedAt: _anchor,
  estimatedOneRm: 196.0,
  rpe: 8.5,
  athleteName: 'Alex Thompson',
);

// ---------------------------------------------------------------------------
// Mock notifiers — extend the public class and override build()
// ---------------------------------------------------------------------------

class _MockActiveSession extends ActiveSessionNotifier {
  @override
  ActiveSessionState? build() => _mockSessionState;
}

class _MockActiveMeet extends ActiveMeetNotifier {
  @override
  Competition? build() => _buildMockMeet();
}

class _MockProgressOverview extends ProgressOverviewNotifier {
  @override
  Future<ProgressOverview> build() async => _mockOverview;
  @override
  Future<void> refresh() async {}
}

class _MockPersonalRecords extends PersonalRecordsNotifier {
  @override
  Future<List<ProgressPersonalRecord>> build() async => _mockPRs;
  @override
  Future<void> refresh() async {}
}

class _MockSbdTotal extends SbdTotalNotifier {
  @override
  Future<SbdTotal> build() async => _mockSbdTotal;
  @override
  Future<void> refresh() async {}
}

class _MockPlanDetail extends PlanDetail {
  @override
  Stream<WorkoutPlan?> build(String planId) => Stream.value(_buildMockPlan());
  @override
  Future<void> refresh() async {}
}

// ---------------------------------------------------------------------------
// Screenshot tests
// ---------------------------------------------------------------------------

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // 01 — Active workout logging: Back Squat with 3 logged sets + RPE badges
  testWidgets('01_workout_logging', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStreamProvider.overrideWith((ref) => Stream.value(_mockProfile)),
          activeSessionProvider.overrideWith(_MockActiveSession.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: IronLogTheme.dark,
          home: const ActiveWorkoutScreen(),
        ),
      ),
    );
    // pump fixed frames — ActiveWorkoutScreen has a live session timer that
    // keeps scheduling frames and would cause pumpAndSettle to loop forever
    await tester.pump(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('01_workout_logging');
  });

  // 02 — Progress dashboard: SBD total, Dots score, personal records
  testWidgets('02_progress_dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStreamProvider.overrideWith((ref) => Stream.value(_mockProfile)),
          progressOverviewProvider.overrideWith(_MockProgressOverview.new),
          personalRecordsProvider.overrideWith(_MockPersonalRecords.new),
          sbdTotalProvider.overrideWith(_MockSbdTotal.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: IronLogTheme.dark,
          home: const ProgressDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('02_progress_dashboard');
  });

  // 03 — Multi-week program calendar: 5/3/1 BBB 4-week block
  testWidgets('03_program_calendar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStreamProvider.overrideWith((ref) => Stream.value(_mockProfile)),
          planDetailProvider('plan1').overrideWith(_MockPlanDetail.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: IronLogTheme.dark,
          home: PlanDetailScreen(planId: 'plan1'),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('03_program_calendar');
  });

  // 04 — Meet day: IPF World Classic attempt grid
  testWidgets('04_meet_day', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStreamProvider.overrideWith((ref) => Stream.value(_mockProfile)),
          activeMeetProvider.overrideWith(_MockActiveMeet.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: IronLogTheme.dark,
          home: const MeetDayScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('04_meet_day');
  });

  // 05 — PR share card (standalone widget, no provider required)
  testWidgets('05_pr_card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: IronLogTheme.dark,
        home: Scaffold(
          backgroundColor: const Color(0xFF1A1A1A),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: PrCard(data: _mockPrCardData, size: 340),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('05_pr_card');
  });

  // 06 — 1RM calculator bottom sheet
  testWidgets('06_one_rm_calculator', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          profileStreamProvider.overrideWith((ref) => Stream.value(_mockProfile)),
          progressOverviewProvider.overrideWith(_MockProgressOverview.new),
          personalRecordsProvider.overrideWith(_MockPersonalRecords.new),
          sbdTotalProvider.overrideWith(_MockSbdTotal.new),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: IronLogTheme.dark,
          home: const ProgressDashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final fab = find.byKey(const Key('oneRmCalcFab'));
    expect(fab, findsOneWidget, reason: '1RM Calc FAB must be visible on progress dashboard');
    await tester.tap(fab);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    await binding.convertFlutterSurfaceToImage();
    await binding.takeScreenshot('06_one_rm_calculator');
  });
}
