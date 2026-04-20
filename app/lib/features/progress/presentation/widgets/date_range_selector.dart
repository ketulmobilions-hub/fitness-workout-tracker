import 'package:flutter/material.dart';

/// A horizontal chip row for selecting a time period.
///
/// [options] is the list of period labels to display (e.g. ['1W', '1M', '3M']).
/// [selected] is the currently active period.
/// [onSelected] fires when the user taps a different period.
class DateRangeSelector extends StatelessWidget {
  const DateRangeSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        spacing: 8,
        children: options.map((option) {
          final isActive = option == selected;
          return ChoiceChip(
            label: Text(option),
            selected: isActive,
            onSelected: (_) => onSelected(option),
            selectedColor: colorScheme.primaryContainer,
            labelStyle: TextStyle(
              color: isActive
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onSurfaceVariant,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Standard period options for the volume chart (dashboard).
const kVolumePeriods = ['1W', '1M', '3M', '6M', '1Y'];

/// Standard period options for exercise progress.
const kExercisePeriods = ['1M', '3M', '6M', '1Y', 'All'];

/// Maps the display label to the API period parameter for volume endpoint.
///
/// Asserts in debug mode if [label] is not in [kVolumePeriods], so developer
/// mistakes are caught immediately. Returns `'1m'` as a safe default in
/// release — this prevents a hard crash if a stale persisted label is ever
/// read after an app update renames a period option (Issue #7).
String volumePeriodToApiParam(String label) {
  assert(
    kVolumePeriods.contains(label),
    'Unknown volume period label: "$label". Add it to kVolumePeriods and this switch.',
  );
  return switch (label) {
    '1W' => '1w',
    '1M' => '1m',
    '3M' => '3m',
    '6M' => '6m',
    '1Y' => '1y',
    _ => '1m', // safe default; unreachable in debug due to assert above
  };
}

/// Maps the display label to the API period parameter for exercise endpoint.
///
/// Asserts in debug mode if [label] is not in [kExercisePeriods].
/// Returns `'3m'` as a safe default in release (see [volumePeriodToApiParam]).
String exercisePeriodToApiParam(String label) {
  assert(
    kExercisePeriods.contains(label),
    'Unknown exercise period label: "$label". Add it to kExercisePeriods and this switch.',
  );
  return switch (label) {
    '1M' => '1m',
    '3M' => '3m',
    '6M' => '6m',
    '1Y' => '1y',
    'All' => 'all',
    _ => '3m', // safe default; unreachable in debug due to assert above
  };
}
