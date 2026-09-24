import 'package:go_router/go_router.dart';

import '../features/home/presentation/home_screen.dart';
import 'route_error_screen.dart';

/// Every route path as a typed constant, instead of a string literal
/// scattered across `context.go('/some/path')` call sites. Add one value
/// per route; `.agents/skills/routing/SKILL.md` covers path parameters and
/// typed `extra` arguments for routes that need more than a path segment.
enum AppRoute {
  home('/home');

  const AppRoute(this.path);

  final String path;
}

/// Builds the app's [GoRouter].
///
/// This is a **function**, not a global singleton — each call returns a
/// fresh, independent router. `lib/app.dart` (at the app root) calls it
/// once for the running app; a widget test calls it again to get an
/// isolated instance instead of racing shared navigation state with other
/// tests. Never promote the result of this function to a top-level
/// `final`/`late` variable.
GoRouter buildAppRouter() => GoRouter(
  initialLocation: AppRoute.home.path,
  errorBuilder: (context, state) => const RouteErrorScreen(),
  routes: [
    // A StatefulShellRoute.indexedStack keeps every branch's navigation
    // stack alive when the user switches tabs (unlike a plain GoRoute,
    // which rebuilds from scratch). It ships with a single `home` branch —
    // see `.agents/skills/routing/SKILL.md` → "Adding a bottom-nav tab" for
    // how to add a second branch and a bottom navigation bar.
    //
    // A screen that needs full-screen immersion (no bottom nav, no shell
    // chrome — e.g. a checkout flow or a media viewer) is registered as a
    // top-level GoRoute here, as a sibling of this StatefulShellRoute, not
    // nested inside a branch.
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => navigationShell,
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: AppRoute.home.path, builder: (context, state) => const HomeScreen()),
          ],
        ),
      ],
    ),
  ],
);
