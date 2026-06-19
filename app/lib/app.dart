import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/providers/connectivity_provider.dart';
import 'core/router/app_router.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/widgets/offline_banner.dart';

class IronLogApp extends ConsumerWidget {
  const IronLogApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize the sync engine so its auth + connectivity listeners
    // are active from app launch. Without this, a keepAlive provider is not
    // created until first read — which could be after auth state has already
    // settled, causing the initial-sync trigger to fire too late.
    ref.watch(syncProvider);

    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'IronLog',
      theme: IronLogTheme.light,
      darkTheme: IronLogTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      // Global offline banner above all navigation chrome. When the banner is
      // visible it occupies the status-bar inset (via its internal SafeArea),
      // so we strip padding.top from MediaQuery for the router child to prevent
      // screens from double-adding the status-bar gap below the banner.
      builder: (context, child) => Consumer(
        builder: (ctx, ref, _) {
          final isConnected = ref.watch(isConnectedProvider);
          return Column(
            children: [
              const OfflineBanner(),
              Expanded(
                child: isConnected
                    ? child!
                    : MediaQuery(
                        data: MediaQuery.of(ctx).copyWith(
                          padding:
                              MediaQuery.of(ctx).padding.copyWith(top: 0),
                        ),
                        child: child!,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
