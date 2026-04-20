/// Domain layer — domain models, repository interfaces, business rules.
library;

export 'src/auth/auth_user.dart';
export 'src/auth/auth_repository.dart';

export 'src/exercises/exercise_type.dart';
export 'src/exercises/muscle_group.dart';
export 'src/exercises/exercise.dart';
export 'src/exercises/exercise_repository.dart';

export 'src/workout_plans/schedule_type.dart';
export 'src/workout_plans/workout_plan.dart';
export 'src/workout_plans/workout_plan_repository.dart';

export 'src/workout_sessions/session_status.dart';
export 'src/workout_sessions/workout_session.dart';
export 'src/workout_sessions/workout_session_summary.dart';
export 'src/workout_sessions/workout_session_repository.dart';

export 'src/progress/progress_overview.dart';
export 'src/progress/exercise_progress.dart';
export 'src/progress/progress_personal_record.dart';
export 'src/progress/volume_data.dart';
export 'src/progress/progress_repository.dart';

export 'src/streaks/streak_day_status.dart';
export 'src/streaks/streak.dart';
export 'src/streaks/streak_day.dart';
export 'src/streaks/streak_repository.dart';
