import 'package:fitness_domain/fitness_domain.dart';
import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/profile/providers/profile_providers.dart';

part 'theme_provider.g.dart';

@Riverpod(keepAlive: true)
ThemeMode themeMode(Ref ref) {
  // Watch the full profile stream; the provider rebuilds only when
  // profileStreamProvider emits — which already fires only on real DB changes.
  // Issue #18 note: falls back to ThemeMode.system while unauthenticated or
  // loading, which may cause a one-frame flash on first login. Storing the
  // last-used theme in SharedPreferences would eliminate the flash but is out
  // of scope for this iteration.
  final themePreference =
      ref.watch(profileStreamProvider).value?.preferences.theme;
  return switch (themePreference) {
    ThemePreference.light => ThemeMode.light,
    ThemePreference.dark => ThemeMode.dark,
    _ => ThemeMode.system,
  };
}
