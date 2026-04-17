import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/sync/sync_service.dart';
import 'core/widgets/offline_banner.dart';

class FitnessApp extends ConsumerWidget {
  const FitnessApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Eagerly initialize the sync engine so its auth + connectivity listeners
    // are active from app launch. Without this, a keepAlive provider is not
    // created until first read — which could be after auth state has already
    // settled, causing the initial-sync trigger to fire too late.
    ref.watch(syncProvider);

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Fitness Tracker',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: router,
      // Global offline banner: wraps every routed page so screens need no
      // per-screen wiring. The banner sits above all navigation chrome.
      builder: (context, child) => Column(
        children: [
          const OfflineBanner(),
          Expanded(child: child!),
        ],
      ),
    );
  }
}
