import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/competition_providers.dart';
import '../widgets/competition_card.dart';
import '../widgets/competition_score_chart.dart';

class CompetitionHistoryScreen extends ConsumerWidget {
  const CompetitionHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final compsAsync = ref.watch(competitionListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Competition History')),
      body: compsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('Failed to load competitions',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: () =>
                    ref.read(competitionListProvider.notifier).refresh(),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (comps) {
          if (comps.isEmpty) return const _EmptyState();

          final upcoming = comps
              .where((c) => c.status == CompetitionStatus.upcoming)
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));

          final pastDescending = comps
              .where((c) => c.status == CompetitionStatus.completed)
              .toList()
            ..sort((a, b) => b.date.compareTo(a.date));

          final pastAscending = [...pastDescending.reversed];

          // Show chart only when a series has enough points to draw a line.
          final hasEnoughDots =
              pastAscending.where((c) => c.dots != null).length >= 2;
          final hasEnoughWilks =
              pastAscending.where((c) => c.wilks != null).length >= 2;

          return CustomScrollView(
            slivers: [
              // Upcoming
              if (upcoming.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionHeader('Upcoming'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => CompetitionCard(
                      comp: upcoming[i],
                      onTap: () => context.push(
                          AppRoutes.competitionDetailPath(upcoming[i].id)),
                    ),
                    childCount: upcoming.length,
                  ),
                ),
              ],

              // Score chart — only if at least one series has ≥2 data points.
              if (hasEnoughDots || hasEnoughWilks)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: CompetitionScoreChart(meets: pastAscending),
                      ),
                    ),
                  ),
                ),

              // Past meets
              if (pastDescending.isNotEmpty) ...[
                const SliverToBoxAdapter(
                  child: _SectionHeader('Past Meets'),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => CompetitionCard(
                      comp: pastDescending[i],
                      onTap: () => context.push(
                          AppRoutes.competitionDetailPath(
                              pastDescending[i].id)),
                    ),
                    childCount: pastDescending.length,
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 64, color: cs.outline),
            const SizedBox(height: 16),
            Text(
              'No meets logged yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Start with your next competition →',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Start a Meet'),
              onPressed: () => context.push(AppRoutes.startMeet),
            ),
          ],
        ),
      ),
    );
  }
}
