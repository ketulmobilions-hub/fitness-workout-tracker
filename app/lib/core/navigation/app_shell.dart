import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_routes.dart';

/// Persistent shell scaffold wrapping the authenticated tab section of the app.
///
/// Hosts a Material 3 [NavigationBar] with 5 items:
///   0 Home  1 Plans  2 Log (action)  3 Progress  4 Profile
///
/// Item 2 is a special action item — tapping it pushes [AppRoutes.activeWorkout]
/// as a full-screen route (no bottom nav during workout). The remaining 4 items
/// map 1-to-1 to [StatefulShellBranch]es (branch indices 0–3).
///
/// Uses [StatefulWidget] so that [_currentIndex] is authoritative in state and
/// [PopScope.canPop] is never stale during tab-switch animations.
class AppShell extends StatefulWidget {
  const AppShell({
    required this.navigationShell,
    required this.branchNavigatorKeys,
    super.key,
  });

  final StatefulNavigationShell navigationShell;

  /// Navigator keys for each branch — used to check whether a branch has a
  /// back-stack before deciding how to handle re-taps and Android back.
  final List<GlobalKey<NavigatorState>> branchNavigatorKeys;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.navigationShell.currentIndex;
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.navigationShell.currentIndex;
    if (newIndex != _currentIndex) {
      setState(() => _currentIndex = newIndex);
    }
  }

  /// Whether the current branch's navigator has entries it can pop.
  bool get _branchCanPop =>
      widget.branchNavigatorKeys[_currentIndex].currentState?.canPop() ?? false;

  // Maps NavigationBar item index → branch index (skips the action item at 2).
  static int _navToBranch(int i) => i > 2 ? i - 1 : i;

  // Maps branch index → NavigationBar item index.
  static int _branchToNav(int i) => i >= 2 ? i + 1 : i;

  void _onDestinationSelected(BuildContext context, int navIndex) {
    if (navIndex == 2) {
      // Log action: push the active workout screen above the shell via the
      // root navigator (parentNavigatorKey on the route ensures this).
      context.push(AppRoutes.activeWorkout);
      return;
    }
    final branchIndex = _navToBranch(navIndex);
    if (branchIndex == _currentIndex) {
      // Re-tap on the active tab: pop to root only when the branch actually
      // has a back-stack to clear — avoids rebuilding the root screen and
      // wiping ephemeral state (e.g. scroll position, search text) when the
      // user is already at the root.
      if (_branchCanPop) {
        widget.navigationShell.goBranch(branchIndex, initialLocation: true);
      }
      return;
    }
    widget.navigationShell.goBranch(branchIndex);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Allow the system to handle back when:
      //   • on the home branch (system back exits the app), or
      //   • the branch has a back-stack to pop.
      // Only intercept when on a non-home branch at its root — redirect to Home.
      canPop: _currentIndex == 0 || _branchCanPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          widget.navigationShell.goBranch(0);
        }
      },
      child: Scaffold(
        body: widget.navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: _branchToNav(_currentIndex),
          onDestinationSelected: (index) =>
              _onDestinationSelected(context, index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: 'Plans',
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: 'Log',
            ),
            NavigationDestination(
              icon: Icon(Icons.insights_outlined),
              selectedIcon: Icon(Icons.insights),
              label: 'Progress',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
