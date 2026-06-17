import 'package:fitness_domain/fitness_domain.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'workout_plan_providers.dart';

part 'template_provider.g.dart';

@riverpod
Future<List<ProgramTemplateSummary>> planTemplates(Ref ref) {
  return ref.read(workoutPlanRepositoryProvider).listTemplates();
}

// keepAlive: true prevents re-fetching a full 12-week template every time the
// user navigates back to the detail screen within a session.
@Riverpod(keepAlive: true)
Future<ProgramTemplate> templateDetail(Ref ref, String templateId) {
  return ref.read(workoutPlanRepositoryProvider).getTemplate(templateId);
}
