import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/plan_list_provider.dart';
import '../widgets/plan_card.dart';

class PlanListScreen extends ConsumerWidget {
  const PlanListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(planListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Plans'),
      ),
      floatingActionButton: const FloatingActionButton(
        tooltip: 'Coming soon',
        onPressed: null,
        child: Icon(Icons.add),
      ),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => ref.read(planListProvider.notifier).refresh(),
              child: ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.event_note_outlined, size: 64),
                          const SizedBox(height: 16),
                          Text(
                            'No workout plans yet.',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create a plan to organise your workouts by day and week.',
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(planListProvider.notifier).refresh(),
            child: ListView.separated(
              itemCount: plans.length,
              separatorBuilder: (ctx, i) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (context, index) {
                final plan = plans[index];
                return PlanCard(
                  plan: plan,
                  onTap: () =>
                      context.push(AppRoutes.planDetailPath(plan.id)),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => RefreshIndicator(
          onRefresh: () => ref.read(planListProvider.notifier).refresh(),
          child: ListView(
            children: [
              const SizedBox(height: 64),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load plans.\nPull down to retry.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
