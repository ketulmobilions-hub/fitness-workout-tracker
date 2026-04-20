import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_routes.dart';
import '../../providers/profile_providers.dart';
import '../widgets/guest_upgrade_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileStreamProvider);
    final statsAsync = ref.watch(userStatsProvider);
    // Issue #7: surface refresh errors when the local cache is also empty.
    final refreshError = ref.watch(profileRefreshErrorProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorRetry(
          message: 'Failed to load profile: $e',
          onRetry: () => ref.invalidate(profileStreamProvider),
        ),
        data: (profile) {
          // Issue #7: cache is empty — show refresh error with retry if available,
          // otherwise a generic message.
          if (profile == null) {
            return _ErrorRetry(
              message: refreshError != null
                  ? 'Could not load profile: $refreshError'
                  : 'No profile data. Check your connection and try again.',
              onRetry: () {
                ref.read(profileRefreshErrorProvider.notifier).clear();
                ref.invalidate(profileStreamProvider);
              },
            );
          }

          final isGuest = profile.isGuest;
          final initials = _initials(profile.displayName, profile.email);

          return RefreshIndicator(
            onRefresh: () async {
              // Issue #16: call refreshProfile directly instead of invalidating
              // the keepAlive stream provider, which would cause a loading flash.
              try {
                await ref
                    .read(profileRepositoryProvider)
                    .refreshProfile(profile.id);
                ref.read(profileRefreshErrorProvider.notifier).clear();
              } catch (e) {
                ref
                    .read(profileRefreshErrorProvider.notifier)
                    .set(e.toString());
              }
              ref.invalidate(userStatsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // -- Avatar + name section
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor:
                            Theme.of(context).colorScheme.primary,
                        backgroundImage: profile.avatarUrl != null
                            ? NetworkImage(profile.avatarUrl!)
                            : null,
                        child: profile.avatarUrl == null
                            ? Text(
                                initials,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onPrimary,
                                    ),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        profile.displayName ??
                            (isGuest ? 'Guest' : 'No name set'),
                        style:
                            Theme.of(context).textTheme.headlineSmall,
                      ),
                      if (!isGuest && profile.email != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          profile.email!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                      if (profile.bio != null &&
                          profile.bio!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          profile.bio!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        'Member since ${DateFormat.yMMMM().format(profile.createdAt)}',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // -- Stats row
                // Issue #15: show retry on stats error instead of silently
                // hiding the section.
                statsAsync.when(
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Could not load stats',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(userStatsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (stats) => Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Row(
                        children: [
                          _StatCell(
                            label: 'Workouts',
                            value: stats.totalWorkouts.toString(),
                          ),
                          _StatCell(
                            label: 'Streak',
                            value: '${stats.currentStreak}d',
                          ),
                          _StatCell(
                            label: 'Volume',
                            value:
                                '${(stats.totalVolumeKg / 1000).toStringAsFixed(1)}t',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // -- Guest upgrade prompt
                if (isGuest) ...[
                  const GuestUpgradeCard(),
                  const SizedBox(height: 16),
                ],

                // -- Actions
                if (!isGuest)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile'),
                    onPressed: () => context.push(AppRoutes.editProfile),
                  ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_outlined),
                  label: const Text('Settings'),
                  onPressed: () => context.push(AppRoutes.settings),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _initials(String? displayName, String? email) {
    if (displayName != null && displayName.isNotEmpty) {
      final parts = displayName.trim().split(' ');
      if (parts.length >= 2) {
        return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      }
      return displayName[0].toUpperCase();
    }
    if (email != null && email.isNotEmpty) return email[0].toUpperCase();
    return '?';
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
