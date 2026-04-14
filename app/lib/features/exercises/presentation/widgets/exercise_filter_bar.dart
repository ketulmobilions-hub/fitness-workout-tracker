import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/exercise_filter_provider.dart';
import '../../providers/exercise_providers.dart';

class ExerciseFilterBar extends ConsumerStatefulWidget {
  const ExerciseFilterBar({super.key});

  @override
  ConsumerState<ExerciseFilterBar> createState() => _ExerciseFilterBarState();
}

class _ExerciseFilterBarState extends ConsumerState<ExerciseFilterBar> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // Seed the controller with the current Riverpod state so the text field
    // stays in sync if the filter provider survived auto-dispose timing and
    // already holds a non-empty search query.
    _searchController = TextEditingController(
      text: ref.read(exerciseFilterProvider).search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(exerciseFilterProvider);
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
                            .read(exerciseFilterProvider.notifier)
                            .setSearch('');
                      },
                    ),
                  ]
                : null,
            onChanged: (value) =>
                ref.read(exerciseFilterProvider.notifier).setSearch(value),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              // Type filter chips
              for (final type in ExerciseType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(_typeLabel(type)),
                    selected: filter.type == type,
                    onSelected: (selected) => ref
                        .read(exerciseFilterProvider.notifier)
                        .setType(selected ? type : null),
                  ),
                ),
              // Muscle group filter chips
              ...muscleGroupsAsync.when(
                data: (groups) => groups.map(
                  (mg) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(mg.displayName),
                      selected: filter.muscleGroupName == mg.name,
                      onSelected: (selected) => ref
                          .read(exerciseFilterProvider.notifier)
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

  String _typeLabel(ExerciseType type) => switch (type) {
        ExerciseType.strength => 'Strength',
        ExerciseType.cardio => 'Cardio',
        ExerciseType.stretching => 'Stretching',
      };
}
