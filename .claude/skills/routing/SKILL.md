---
name: routing
description: Explains how to add a route in app_router.dart — the AppRoute enum, choosing between the StatefulShellRoute and a top-level GoRoute, why buildAppRouter() must stay a function, typed arguments via state.extra with a redirect type guard, path parameters, and adding a second bottom-nav branch; triggers whenever a new screen needs a route or the shell gains a tab.
---

# Adding or changing a route

Routing is `go_router` via `packages/ui/lib/src/router/app_router.dart`
(root `AGENTS.md` section 10). Every destination is a typed `AppRoute` enum
value, never a string literal at the call site.

## 1. Add an `AppRoute` value

```dart
enum AppRoute {
  home('/home'),
  taskDetail('/task/:id');

  const AppRoute(this.path);

  final String path;
}
```

Every navigation call references `AppRoute.taskDetail.path` (or
`context.go`/`context.push` built from it), never a hand-typed
`'/task/:id'` string scattered across the codebase.

## 2. Shell branch vs top-level sibling `GoRoute`

Ask: does this screen keep the app's persistent navigation chrome (bottom
nav bar, drawer) visible, or does it need full immersion?

- **Persistent navigation chrome** → nest the `GoRoute` inside the
  existing `StatefulShellRoute.indexedStack`'s branch:

  ```dart
  StatefulShellRoute.indexedStack(
    builder: (context, state, navigationShell) => navigationShell,
    branches: [
      StatefulShellBranch(
        routes: [
          GoRoute(path: AppRoute.home.path, builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: AppRoute.taskDetail.path,
            builder: (context, state) => TaskDetailScreen(taskId: state.pathParameters['id']!),
          ),
        ],
      ),
    ],
  );
  ```

  A `StatefulShellRoute.indexedStack` keeps every branch's navigation
  stack alive when switching tabs (unlike a plain `GoRoute`, which rebuilds
  from scratch) — see the `TickerMode` implication for animated widgets in
  `.agents/skills/ui-screen/SKILL.md`.

- **Full immersion (no shell chrome)** — a checkout flow, a media viewer,
  an active session screen — → register it as a **top-level `GoRoute`**, a
  sibling of `StatefulShellRoute`, not nested inside a branch:

  ```dart
  GoRouter buildAppRouter() => GoRouter(
    initialLocation: AppRoute.home.path,
    errorBuilder: (context, state) => const RouteErrorScreen(),
    routes: [
      StatefulShellRoute.indexedStack(/* ... */),
      GoRoute(
        path: AppRoute.taskEditor.path,
        builder: (context, state) => const TaskEditorScreen(),
      ),
    ],
  );
  ```

## 3. Why `buildAppRouter()` is a function, never a singleton

`buildAppRouter()` must stay a plain function that returns a fresh
`GoRouter` on every call — never memoized into a top-level `final`/`late`
variable. `lib/bootstrap.dart` calls it once for the running app; a widget
test calls it again to get its own isolated router instance instead of
racing shared navigation state with every other test in the suite. This is
exactly what `packages/ui/test/router/app_router_test.dart` relies on:

```dart
Future<void> pumpRouter(WidgetTester tester) {
  // A fresh router per test — this is exactly why buildAppRouter() must
  // stay a function and not a memoized singleton.
  final router = buildAppRouter();
  return tester.pumpWidget(/* ... MaterialApp.router(routerConfig: router) ... */);
}
```

If `buildAppRouter()` were memoized, one test navigating away from `/home`
would leak into the next test's initial location, and tests would start
failing depending on run order.

## 4. Typed arguments via `state.extra` + a redirect type guard

`state.pathParameters` is for plain id strings only (`:id` → a `String`).
For anything richer — a typed object the destination screen needs — pass
it via `state.extra` and add a `redirect` that checks the runtime type
before the screen ever builds, bouncing back to a safe route if a caller
navigated here without the expected argument (e.g. a deep link, or a
programming mistake):

```dart
// A UI-only navigation argument — lives in the feature's models/ folder,
// not domain (it's not a business entity, just what this route needs).
class TaskEditorArgs {
  const TaskEditorArgs({required this.taskId, required this.initialTitle});

  final String taskId;
  final String initialTitle;
}

GoRoute(
  path: AppRoute.taskEditor.path,
  redirect: (context, state) {
    if (state.extra is! TaskEditorArgs) {
      return AppRoute.home.path;
    }
    return null; // null keeps the match, only a non-null String redirects.
  },
  builder: (context, state) => TaskEditorScreen(args: state.extra! as TaskEditorArgs),
);
```

Navigate to it with:

```dart
context.push(AppRoute.taskEditor.path, extra: TaskEditorArgs(taskId: task.id, initialTitle: task.title));
```

The `redirect` guard matters because `state.extra` is untyped (`Object?`)
at the `go_router` level — without the guard, a bad/missing `extra` would
only fail at the `as TaskEditorArgs` cast inside `builder`, deep in the
widget tree, instead of being caught and redirected before any UI is
built.

## 5. Path parameters for plain ids

A route segment that's just an identifier uses `state.pathParameters`
directly — no `extra`, no redirect guard needed, since a `String` can't
fail a type check:

```dart
GoRoute(
  path: AppRoute.taskDetail.path, // '/task/:id'
  builder: (context, state) => TaskDetailScreen(taskId: state.pathParameters['id']!),
);
```

## 6. Adding a second `StatefulShellBranch` (a bottom-nav tab)

The router currently ships with a **single** branch, so
`StatefulShellRoute.indexedStack`'s `builder` renders `navigationShell`
directly with no visible bottom-nav bar — there's nothing to switch
between yet. Adding a second branch means the shell now needs chrome to
switch branches, so wrap `navigationShell` in a `Scaffold` with a
`NavigationBar` (or `BottomNavigationBar`) driven by
`navigationShell.currentIndex` and `navigationShell.goBranch(index)`:

```dart
GoRouter buildAppRouter() => GoRouter(
  initialLocation: AppRoute.home.path,
  errorBuilder: (context, state) => const RouteErrorScreen(),
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => Scaffold(
        body: navigationShell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          // goBranch preserves each branch's own navigation stack; passing
          // initialLocation: true when re-tapping the already-selected tab
          // resets that branch back to its own start, matching platform
          // bottom-nav convention.
          onDestinationSelected: (index) => navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          ),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.home_outlined), label: context.l10n.homeTabLabel),
            NavigationDestination(icon: const Icon(Icons.list_alt_outlined), label: context.l10n.tasksTabLabel),
          ],
        ),
      ),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoute.home.path, builder: (context, state) => const HomeScreen())],
        ),
        StatefulShellBranch(
          routes: [GoRoute(path: AppRoute.tasks.path, builder: (context, state) => const TaskListScreen())],
        ),
      ],
    ),
  ],
);
```

Each `NavigationDestination` label is a localized string via
`context.l10n`, per the zero-hardcoded-strings rule — see
`.agents/skills/localization/SKILL.md`.

## Common mistakes

- Hand-typing a path string (`context.go('/task/1')`) instead of building
  it from `AppRoute`.
- Memoizing `buildAppRouter()`'s result into a top-level variable — breaks
  test isolation immediately.
- Using `state.extra` for a plain id (just use `state.pathParameters`
  instead) or `state.pathParameters` for a typed object it can't express.
- Skipping the `redirect` type guard on a `state.extra` route — the
  failure then surfaces as an unhandled cast exception deep in `builder`
  instead of a clean redirect.
- Nesting a full-immersion screen inside a shell branch (it will render
  with the bottom-nav bar still visible) or putting a persistent-nav
  screen as a top-level sibling (it loses the shell chrome and its
  branch's preserved navigation stack).

## Checklist

- [ ] New `AppRoute` enum value added, referenced everywhere instead of a
      string literal.
- [ ] Route placed inside the shell branch (persistent chrome) or as a
      top-level sibling `GoRoute` (full immersion) — deliberately, not by
      default.
- [ ] `buildAppRouter()` was not memoized into a singleton.
- [ ] A typed argument uses `state.extra` with a `redirect` type guard; a
      plain id uses `state.pathParameters`.
- [ ] A route test exists, building a fresh `buildAppRouter()` instance
      (see `.agents/skills/testing/SKILL.md`).
