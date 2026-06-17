class TemplateExercise {
  const TemplateExercise({
    required this.exerciseName,
    required this.sortOrder,
    required this.targetSets,
    this.targetReps,
    this.targetWeightPct1rm,
    this.targetRpe,
    this.notes,
  });

  final String exerciseName;
  final int sortOrder;
  final int targetSets;
  final String? targetReps;
  final double? targetWeightPct1rm;
  final double? targetRpe;
  final String? notes;
}

class TemplateDay {
  const TemplateDay({
    required this.dayOfWeek,
    required this.name,
    required this.sortOrder,
    required this.exercises,
  });

  final int dayOfWeek;
  final String name;
  final int sortOrder;
  final List<TemplateExercise> exercises;

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  String get dayName => _dayNames[dayOfWeek];
}

class TemplateWeek {
  const TemplateWeek({
    required this.weekNumber,
    required this.days,
  });

  final int weekNumber;
  final List<TemplateDay> days;
}

class ProgramTemplateSummary {
  const ProgramTemplateSummary({
    required this.id,
    required this.name,
    required this.description,
    required this.weeksCount,
    required this.daysPerWeek,
    required this.difficulty,
    required this.category,
    required this.tags,
  });

  final String id;
  final String name;
  final String description;
  final int weeksCount;
  final int daysPerWeek;
  final String difficulty;
  final String category;
  final List<String> tags;
}

class ProgramTemplate extends ProgramTemplateSummary {
  const ProgramTemplate({
    required super.id,
    required super.name,
    required super.description,
    required super.weeksCount,
    required super.daysPerWeek,
    required super.difficulty,
    required super.category,
    required super.tags,
    required this.weeks,
  });

  final List<TemplateWeek> weeks;

  // Week 1 day 1 — used for the preview screen.
  TemplateDay? get previewDay =>
      weeks.isNotEmpty && weeks.first.days.isNotEmpty
          ? weeks.first.days.first
          : null;
}

class TemplateImportResult {
  const TemplateImportResult({required this.planId});
  final String planId;
}
