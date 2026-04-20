import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../exercises/providers/exercise_providers.dart';
import '../../providers/exercise_picker_filter_provider.dart';
import '../widgets/exercise_type_icon.dart';

/// Returns the display label for an [ExerciseType].
String _typeLabel(ExerciseType type) => switch (type) {
      ExerciseType.strength => 'Strength',
      ExerciseType.cardio => 'Cardio',
      ExerciseType.stretching => 'Stretching',
    };

/// Full-screen exercise picker with search, type/muscle-group filters, and
/// multi-select. Launched via [Navigator.of(context).push] (not GoRouter) so
/// it can return the selected [Exercise] list to the caller.
class ExercisePickerScreen extends ConsumerStatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  ConsumerState<ExercisePickerScreen> createState() =>
      _ExercisePickerScreenState();
}

class _ExercisePickerScreenState
    extends ConsumerState<ExercisePickerScreen> {
  final Set<String> _selectedIds = {};
  final Map<String, Exercise> _exerciseCache = {};

  @override
  Widget build(BuildContext context) {
    // Use the BL-layer provider — never call the repository directly from
    // the presentation layer (VGV contract).
    final exercisesAsync = ref.watch(exercisePickerListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Exercises'),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _confirm,
              child: Text('Add (${_selectedIds.length})'),
            ),
        ],
      ),
      body: Column(
        children: [
          _PickerFilterBar(),
          Expanded(
            child: exercisesAsync.when(
              error: (e, s) => Center(
                child: Text(
                  'Could not load exercises.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              data: (exercises) {
                if (exercises.isEmpty) {
                  return const Center(child: Text('No exercises found.'));
                }
                // Cache all visible exercises so we can look them up on confirm.
                for (final ex in exercises) {
                  _exerciseCache[ex.id] = ex;
                }
                return ListView.builder(
                  itemCount: exercises.length,
                  itemBuilder: (context, index) {
                    final ex = exercises[index];
                    final selected = _selectedIds.contains(ex.id);
                    return CheckboxListTile(
                      value: selected,
                      onChanged: (_) => setState(() {
                        if (selected) {
                          _selectedIds.remove(ex.id);
                        } else {
                          _selectedIds.add(ex.id);
                        }
                      }),
                      title: Text(ex.name),
                      subtitle: Text(
                        _typeLabel(ex.exerciseType),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                      secondary: ExerciseTypeIcon(
                        type: ex.exerciseType,
                        size: 20,
                      ),
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIds.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _confirm,
              icon: const Icon(Icons.check),
              label: Text('Add ${_selectedIds.length}'),
            ),
    );
  }

  void _confirm() {
    final selected = _selectedIds
        .map((id) => _exerciseCache[id])
        .whereType<Exercise>()
        .toList();
    Navigator.of(context).pop(selected);
  }
}

// ---------------------------------------------------------------------------
// Picker-specific filter bar (uses exercisePickerFilterProvider)
// ---------------------------------------------------------------------------

class _PickerFilterBar extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PickerFilterBar> createState() => _PickerFilterBarState();
}

class _PickerFilterBarState extends ConsumerState<_PickerFilterBar> {
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(exercisePickerFilterProvider).search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(exercisePickerFilterProvider);
    final muscleGroupsAsync = ref.watch(muscleGroupsProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SearchBar(
            controller: _searchController,
            hintText: 'Search exercises...',
            leading: const Icon(Icons.search),
            trailing: filter.search.isNotEmpty
                ? [
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        ref
                            .read(exercisePickerFilterProvider.notifier)
                            .setSearch('');
                      },
                    ),
                  ]
                : null,
            onChanged: (value) => ref
                .read(exercisePickerFilterProvider.notifier)
                .setSearch(value),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              for (final type in ExerciseType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(_typeLabel(type)),
                    selected: filter.type == type,
                    onSelected: (selected) => ref
                        .read(exercisePickerFilterProvider.notifier)
                        .setType(selected ? type : null),
                  ),
                ),
              ...muscleGroupsAsync.when(
                data: (groups) => groups.map(
                  (mg) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(mg.displayName),
                      selected: filter.muscleGroupName == mg.name,
                      onSelected: (selected) => ref
                          .read(exercisePickerFilterProvider.notifier)
                          .setMuscleGroup(selected ? mg.name : null),
                    ),
                  ),
                ),
                loading: () => const [],
                error: (e, s) => const [],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
