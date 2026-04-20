import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../auth/providers/auth_notifier.dart';
import '../../../auth/providers/auth_state.dart';
import '../../../workout_plans/providers/workout_plan_providers.dart';
import '../../providers/profile_providers.dart';
import '../widgets/guest_upgrade_card.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final isGuest = authState is AuthGuest;
    final profileAsync = ref.watch(profileStreamProvider);
    final profile = profileAsync.value;
    final prefs = profile?.preferences ?? const UserPreferences();
    final userId = ref.watch(stableUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // -- Preferences section
          const _SectionHeader(title: 'Preferences'),
          if (isGuest) ...[
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Preferences are saved to your account. Sign up to unlock them.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  const GuestUpgradeCard(),
                ],
              ),
            ),
          ] else ...[
            // Units
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Units',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<UnitsPreference>(
                    segments: const [
                      ButtonSegment(
                          value: UnitsPreference.metric,
                          label: Text('Metric (kg / km)')),
                      ButtonSegment(
                          value: UnitsPreference.imperial,
                          label: Text('Imperial (lbs / mi)')),
                    ],
                    selected: {prefs.units},
                    onSelectionChanged: (v) => _updatePrefs(
                        context, ref, userId,
                        prefs.copyWith(units: v.first)),
                  ),
                ],
              ),
            ),
            // Theme
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Theme',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  SegmentedButton<ThemePreference>(
                    segments: const [
                      ButtonSegment(
                          value: ThemePreference.light,
                          label: Text('Light'),
                          icon: Icon(Icons.light_mode)),
                      ButtonSegment(
                          value: ThemePreference.dark,
                          label: Text('Dark'),
                          icon: Icon(Icons.dark_mode)),
                      ButtonSegment(
                          value: ThemePreference.system,
                          label: Text('System'),
                          icon: Icon(Icons.brightness_auto)),
                    ],
                    selected: {prefs.theme},
                    onSelectionChanged: (v) => _updatePrefs(
                        context, ref, userId,
                        prefs.copyWith(theme: v.first)),
                  ),
                ],
              ),
            ),
            // Notifications
            const _SectionSubHeader(title: 'Notifications'),
            SwitchListTile(
              title: const Text('Workout Reminders'),
              value: prefs.notifications.workoutReminders,
              onChanged: (v) => _updatePrefs(
                context, ref, userId,
                prefs.copyWith(
                  notifications:
                      prefs.notifications.copyWith(workoutReminders: v),
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Streak Alerts'),
              value: prefs.notifications.streakAlerts,
              onChanged: (v) => _updatePrefs(
                context, ref, userId,
                prefs.copyWith(
                  notifications:
                      prefs.notifications.copyWith(streakAlerts: v),
                ),
              ),
            ),
            SwitchListTile(
              title: const Text('Weekly Report'),
              value: prefs.notifications.weeklyReport,
              onChanged: (v) => _updatePrefs(
                context, ref, userId,
                prefs.copyWith(
                  notifications:
                      prefs.notifications.copyWith(weeklyReport: v),
                ),
              ),
            ),
          ],

          const Divider(),

          // -- Account section
          const _SectionHeader(title: 'Account'),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Linked Accounts'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Export My Data'),
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Coming soon')),
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined,
                color: Theme.of(context).colorScheme.error),
            title: Text(
              'Delete Account',
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
              ),
            ),
            onTap: userId != null
                ? () => _confirmDeleteAccount(context, ref, userId)
                : null,
          ),

          const Divider(),

          // -- About section
          const _SectionHeader(title: 'About'),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) {
              final version = snap.data != null
                  ? 'v${snap.data!.version}+${snap.data!.buildNumber}'
                  : '';
              return ListTile(
                title: const Text('App Version'),
                trailing: Text(version,
                    style: Theme.of(context).textTheme.bodySmall),
              );
            },
          ),
          ListTile(
            title: const Text('Open Source Licenses'),
            onTap: () => showLicensePage(context: context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // Issue #11: preference errors are now shown to the user via a SnackBar
  // instead of being silently discarded.
  Future<void> _updatePrefs(
    BuildContext context,
    WidgetRef ref,
    String? userId,
    UserPreferences prefs,
  ) async {
    if (userId == null) return;
    try {
      await ref.read(profileRepositoryProvider).updatePreferences(userId, prefs);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save preference: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteAccount(
      BuildContext context, WidgetRef ref, String userId) async {
    // Issue #14: controller is created here and disposed in a try/finally
    // block, preventing the memory leak from the dialog builder.
    final controller = TextEditingController();
    final bool confirmed;
    try {
      confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Delete Account'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This will permanently delete your account and all data. '
                    'Type DELETE to confirm.',
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(hintText: 'DELETE'),
                    autofocus: true,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  ),
                  onPressed: () => Navigator.of(ctx)
                      .pop(controller.text.trim() == 'DELETE'),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ) ??
          false;
    } finally {
      controller.dispose();
    }

    if (!confirmed) return;

    try {
      // Issue #3/13: deleteAccount now deletes the local Drift row too
      // (via the updated repository impl).
      await ref.read(profileRepositoryProvider).deleteAccount(userId);
      // Issue #12: only call logout() — GoRouter's redirect listener will
      // navigate to the login screen automatically. Calling context.go()
      // here as well races with the router and can stack two login screens.
      ref.read(authProvider.notifier).logout();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete account: $e')),
        );
      }
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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

class _SectionSubHeader extends StatelessWidget {
  const _SectionSubHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
