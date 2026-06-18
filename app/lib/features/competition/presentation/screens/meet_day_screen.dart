import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/competition_providers.dart';
import '../widgets/attempt_cell.dart';
import '../widgets/meet_total_banner.dart';

class MeetDayScreen extends ConsumerWidget {
  const MeetDayScreen({super.key});

  static const _lifts = [LiftType.squat, LiftType.bench, LiftType.deadlift];
  static const _liftLabels = {
    LiftType.squat: 'Squat',
    LiftType.bench: 'Bench',
    LiftType.deadlift: 'Deadlift',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final comp = ref.watch(activeMeetProvider);

    if (comp == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Meet Day')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No active meet.'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => context.go(AppRoutes.startMeet),
                child: const Text('Start a Meet'),
              ),
            ],
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;

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
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Column headers
                  const _AttemptHeader(),
                  const SizedBox(height: 8),
                  // One row per lift
                  for (final lift in _lifts) ...[
                    _LiftRow(
                      label: _liftLabels[lift]!,
                      lift: lift,
                      comp: comp,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          MeetTotalBanner(comp: comp),
        ],
      ),
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
        const SizedBox(width: 80), // lift label column
        Expanded(child: Center(child: Text('Opener', style: style))),
        Expanded(child: Center(child: Text('2nd', style: style))),
        Expanded(child: Center(child: Text('3rd', style: style))),
      ],
    );
  }
}

class _LiftRow extends ConsumerWidget {
  const _LiftRow({
    required this.label,
    required this.lift,
    required this.comp,
  });

  final String label;
  final LiftType lift;
  final Competition comp;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Find the best successful attempt for the label color indicator.
    final best = comp.attempts
        .where((a) => a.liftType == lift && a.result == AttemptResult.goodLift)
        .fold<double?>(null, (best, a) => best == null || a.weightKg > best ? a.weightKg : best);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 80,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (best != null)
                Text(
                  '${best.toStringAsFixed(1)} kg',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
            ],
          ),
        ),
        for (int attempt = 1; attempt <= 3; attempt++) ...[
          Expanded(
            child: AttemptCell(
              competition: comp,
              liftType: lift,
              attemptNumber: attempt,
              onSaved: (weightKg, result) async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(activeMeetProvider.notifier).logAttempt(
                        liftType: lift.name,
                        attemptNumber: attempt,
                        weightKg: weightKg,
                        result: result,
                      );
                } catch (e) {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Failed to save attempt. Try again.')),
                  );
                }
              },
            ),
          ),
          if (attempt < 3) const SizedBox(width: 6),
        ],
      ],
    );
  }
}
