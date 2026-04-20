import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/connectivity_provider.dart';

/// Full-width banner shown at the top of every screen when the device has no
/// network connection. Animates in and out as connectivity changes.
///
/// Mounted via [MaterialApp.router]'s `builder:` parameter in [FitnessApp] so
/// it appears globally without any per-screen wiring.
class OfflineBanner extends ConsumerWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isConnected = ref.watch(isConnectedProvider);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => SizeTransition(
        sizeFactor: animation,
        child: child,
      ),
      child: isConnected
          // Issue 4: explicit key on both children so AnimatedSwitcher always
          // has stable identifiers for both states — prevents janky transitions
          // when connectivity toggles rapidly (e.g., subway tunnels).
          ? const SizedBox.shrink(key: ValueKey('online'))
          : ColoredBox(
              key: const ValueKey('offline-banner'),
              color: Colors.amber.shade700,
              child: SafeArea(
                bottom: false,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.wifi_off,
                          size: 16,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        // Issue 5: Flexible + ellipsis prevents overflow on
                        // small screens in landscape (e.g., workout logging
                        // with phone flat on a bench).
                        Flexible(
                          child: Text(
                            'You\'re offline · Changes will sync on reconnect',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
