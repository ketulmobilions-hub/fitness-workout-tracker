import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/competition_providers.dart';
import '../widgets/attempt_cell.dart';
import '../widgets/competition_card.dart';
import '../widgets/meet_total_banner.dart';

class CompetitionDetailScreen extends ConsumerWidget {
  const CompetitionDetailScreen({super.key, required this.competitionId});

  final String competitionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compsAsync = ref.watch(competitionListProvider);

    return compsAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Failed to load meet details.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(competitionListProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (comps) {
        Competition? comp;
        for (final c in comps) {
          if (c.id == competitionId) {
            comp = c;
            break;
          }
        }
        if (comp == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Meet Details')),
            body: const Center(child: Text('Meet not found.')),
          );
        }
        return _DetailBody(comp: comp);
      },
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.comp});
  final Competition comp;

  static const _lifts = [LiftType.squat, LiftType.bench, LiftType.deadlift];
  static const _liftLabels = {
    LiftType.squat: 'Squat',
    LiftType.bench: 'Bench',
    LiftType.deadlift: 'Deadlift',
  };

  CompetitionAttempt? _attempt(LiftType lift, int number) =>
      comp.attempts
          .where(
              (a) => a.liftType == lift && a.attemptNumber == number)
          .firstOrNull;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(comp.name),
        actions: [
          if (comp.federation != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  comp.federation!,
                  style: tt.labelMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Meet metadata
                  _MetaRow(comp: comp),
                  const SizedBox(height: 20),

                  // Column headers
                  const _AttemptHeader(),
                  const SizedBox(height: 8),

                  // Lift rows
                  for (final lift in _lifts) ...[
                    _LiftRow(
                      label: _liftLabels[lift]!,
                      lift: lift,
                      attempts: [
                        _attempt(lift, 1),
                        _attempt(lift, 2),
                        _attempt(lift, 3),
                      ],
                      cs: cs,
                      tt: tt,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          if (comp.total != null)
            MeetTotalBanner(comp: comp),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.comp});
  final Competition comp;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final chips = <String>[
      CompetitionCard.formatDate(comp.date),
      if (comp.location != null) comp.location!,
      if (comp.division != null) comp.division!,
      if (comp.weightClassKg != null) '${comp.weightClassKg!.toStringAsFixed(0)}kg class',
      if (comp.bodyweightKg != null) 'BW ${comp.bodyweightKg!.toStringAsFixed(1)}kg',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: chips
          .map(
            (c) => Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(c,
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          )
          .toList(),
    );
  }
}

class _AttemptHeader extends StatelessWidget {
  const _AttemptHeader();

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        );
    return Row(
      children: [
        const SizedBox(width: 80),
        Expanded(child: Center(child: Text('Opener', style: style))),
        Expanded(child: Center(child: Text('2nd', style: style))),
        Expanded(child: Center(child: Text('3rd', style: style))),
      ],
    );
  }
}

class _LiftRow extends StatelessWidget {
  const _LiftRow({
    required this.label,
    required this.lift,
    required this.attempts,
    required this.cs,
    required this.tt,
  });

  final String label;
  final LiftType lift;
  final List<CompetitionAttempt?> attempts;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final best = attempts
        .whereType<CompetitionAttempt>()
        .where((a) => a.result == AttemptResult.goodLift)
        .fold<double?>(
            null, (b, a) => b == null || a.weightKg > b ? a.weightKg : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (best != null)
                Text(
                  '${best.toStringAsFixed(1)} kg',
                  style: tt.labelSmall?.copyWith(color: cs.primary),
                ),
            ],
          ),
        ),
        for (int i = 0; i < 3; i++) ...[
          Expanded(child: AttemptResultDisplay(attempt: attempts[i])),
          if (i < 2) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
