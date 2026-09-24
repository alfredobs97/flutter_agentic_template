---
name: ui-screen
description: Walks through building a Flutter screen in this template's presentation layer — feature folder layout, the Screen/View split, loading/empty/error/loaded states, design tokens instead of magic numbers, context.theme/context.l10n, the minimal-parameters rule for _build* helpers, accessibility, and the TickerMode gotcha for shell-branch animations; triggers whenever a new screen or screen-local widget is being built.
---

# Building a screen

This skill covers the full workflow for a new screen in `packages/ui`,
beyond the state-management half (see
`.agents/skills/state-management/SKILL.md` for the Cubit/state side of the
same screen).

## 1. Where the files live

```
packages/ui/lib/src/features/<feature>/
├── bloc/                       # Cubit/BLoC + state (+ event, if a Bloc)
│   └── bloc.dart                 # barrel
├── presentation/
│   ├── <feature>_screen.dart     # public XScreen + private _XView
│   ├── widgets/                  # screen-local widgets, not reused elsewhere
│   │   └── task_card.dart
│   └── presentation.dart         # barrel
├── models/                     # optional: UI-only value types (form drafts,
│   └── ...                       # nav arguments) — not domain entities
└── <feature>.dart              # barrel, exported from features/features.dart
```

`features/home/` (`packages/ui/lib/src/features/home/`) is the shipped
worked example of the `presentation/` half of this layout — it has no
`bloc/` of its own because it only reads the app-wide `FeatureFlagCubit`.
Every directory of three or more related files gets a barrel (root
`AGENTS.md` section 13); export the new feature's barrel from
`packages/ui/lib/src/features/features.dart`.

## 2. The Screen/View split, worked in full

A screen with loading/empty/error/loaded phases — the shape most list
screens take:

```dart
// presentation/task_list_screen.dart
import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../theme/theme.dart';
import '../bloc/bloc.dart';
import 'widgets/task_card.dart';

class TaskListScreen extends StatelessWidget {
  const TaskListScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (context) => TaskListCubit(context.read<TaskRepository>())..load(),
    child: const _TaskListView(),
  );
}

class _TaskListView extends StatelessWidget {
  const _TaskListView();

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.taskListTitle)),
    body: BlocBuilder<TaskListCubit, TaskListState>(builder: _buildBody),
  );

  static Widget _buildBody(BuildContext context, TaskListState state) => switch (state.status) {
    TaskListStatus.initial ||
    TaskListStatus.loading => const Center(child: CircularProgressIndicator()),
    TaskListStatus.error => _buildError(context, state),
    TaskListStatus.loaded when state.tasks.isEmpty => _buildEmpty(context),
    TaskListStatus.loaded => _buildList(context, state),
  };

  static Widget _buildError(BuildContext context, TaskListState state) => Center(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.pageMargin),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _errorMessage(context, state.error!),
            style: context.theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.stackMd),
          FilledButton(
            onPressed: () => context.read<TaskListCubit>().load(),
            child: Text(context.l10n.retryButtonLabel),
          ),
        ],
      ),
    ),
  );

  static Widget _buildEmpty(BuildContext context) => Center(
    child: Semantics(
      label: context.l10n.taskListEmptyStateLabel,
      child: Text(context.l10n.taskListEmptyStateMessage, style: context.theme.textTheme.bodyLarge),
    ),
  );

  static Widget _buildList(BuildContext context, TaskListState state) => ListView.separated(
    padding: const EdgeInsets.all(AppSpacing.pageMargin),
    itemCount: state.tasks.length,
    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.stackSm),
    itemBuilder: (context, index) => TaskCard(task: state.tasks[index]),
  );

  static String _errorMessage(BuildContext context, TaskListError error) => switch (error) {
    TaskListError.connectivity => context.l10n.connectivityErrorMessage,
    TaskListError.unexpected => context.l10n.genericErrorMessage,
  };
}
```

`TaskCard` lives in `presentation/widgets/task_card.dart` because it's
local to this one feature. If a second feature later needs the same
card, promote it to `common_widgets/` (see
`.agents/skills/theming/SKILL.md`) — not before.

## 3. Design tokens instead of magic numbers

Never write `SizedBox(height: 16)`, `Color(0xFF...)`, or
`TextStyle(fontSize: 14)` inline. Use the tokens from
`packages/ui/lib/src/theme/`:

```dart
// Wrong
const SizedBox(height: 16);
Container(color: const Color(0xFF6750A4));
Text('Title', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold));

// Right
const SizedBox(height: AppSpacing.stackMd);
Container(color: context.theme.colorScheme.primary);
Text(context.l10n.taskListTitle, style: context.theme.textTheme.titleLarge);
```

`AppSpacing` (`packages/ui/lib/src/theme/app_spacing.dart`) is the 4pt
scale plus semantic aliases (`pageMargin`, `gutter`, `stackSm/Md/Lg`,
`radiusSm/Md/Lg`). Prefer the semantic alias over the raw `spaceN`
constant when one fits. Colors come from `context.theme.colorScheme` for
anything with a Material role, or `AppColors` (`app_colors.dart`) for the
handful of semantic roles Material doesn't cover (`success`, `warning`).
Text styles come from `context.theme.textTheme`, never a hand-built
`TextStyle`.

## 4. `context.theme` / `context.l10n`, never the raw lookup

`packages/ui/lib/src/theme/context_extensions.dart` defines
`BuildContextX`:

```dart
// Wrong
Theme.of(context).colorScheme.primary;
AppLocalizations.of(context)!.taskListTitle;

// Right
context.theme.colorScheme.primary;
context.l10n.taskListTitle;
```

If a build helper needs another value that's always derivable from
`BuildContext` (a commonly-read provider, for instance), add a getter to
`BuildContextX` rather than calling `Theme.of`/`context.read<X>()` ad hoc
across many files (root `AGENTS.md` section 15).

## 5. The minimal-parameters rule for `_build*` helpers

A private `_build*`/helper widget-building method takes, by default, **at
most a single `BuildContext context` parameter**. Add a further parameter
only for data that is *not* obtainable from `context` — typically
widget-local state handed down from a `BlocBuilder`'s `state`. This
applies recursively: a helper called by another helper still receives
only `BuildContext` plus its own non-context-derivable data (root
`AGENTS.md` section 15, exact wording).

```dart
// Wrong — ThemeData and AppLocalizations are both derivable from context
Widget _buildError(BuildContext context, ThemeData theme, AppLocalizations l10n, TaskListError error) => ...

// Right — only the one thing NOT derivable from context (the error value) is threaded
Widget _buildError(BuildContext context, TaskListError error) => ...

// Right — a helper with nothing beyond context takes only context
Widget _buildEmpty(BuildContext context) => ...
```

Never pass `ThemeData`, `AppLocalizations`, or a Cubit/Bloc instance as an
explicit parameter when `context.theme`, `context.l10n`, or
`context.read<X>()` inside the method body achieves the same result.

## 6. Accessibility

Wrap an interactive element or a meaningful non-text visual (an icon-only
button, an empty-state illustration) in `Semantics` with a localized
`label`, and prefer widgets that already carry semantics (`IconButton`'s
`tooltip`, `FilledButton`'s text child) over a bare `GestureDetector`:

```dart
Semantics(
  button: true,
  label: context.l10n.deleteTaskButtonLabel,
  child: IconButton(
    icon: const Icon(Icons.delete_outline),
    tooltip: context.l10n.deleteTaskButtonLabel,
    onPressed: () => context.read<TaskListCubit>().delete(task.id),
  ),
);
```

Every such label is a localized string from `context.l10n` — never a
hardcoded literal (see `.agents/skills/localization/SKILL.md`).

## 7. The `TickerMode` gotcha inside a shell branch

`StatefulShellRoute.indexedStack` (used by `buildAppRouter()`, see
`.agents/skills/routing/SKILL.md`) keeps every branch mounted when the
user switches tabs, wrapping inactive branches in
`TickerMode(enabled: false)` rather than disposing them (root `AGENTS.md`
section 16). An `AnimationController` that calls `..repeat()`
unconditionally keeps ticking — burning CPU and battery — after the user
navigates to a different tab, because the widget is still alive, just
not visible.

```dart
class _PulsingBadge extends StatefulWidget {
  const _PulsingBadge();

  @override
  State<_PulsingBadge> createState() => _PulsingBadgeState();
}

class _PulsingBadgeState extends State<_PulsingBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Gate on TickerMode so the animation stops (and its ticks don't keep
    // firing) while this branch is inactive, and resumes when it's active
    // again — instead of an unconditional `..repeat()` in initState.
    if (TickerMode.of(context)) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _controller, child: const Icon(Icons.circle));
}
```

If the animation isn't load-bearing (a decorative flourish, not a loading
indicator the user is waiting on), the simplest fix is often to just skip
it rather than wire up `TickerMode` handling at all.

## Common mistakes

- Styling a widget type inline at every call site instead of adding a
  sub-theme to `AppTheme` (see `.agents/skills/theming/SKILL.md`).
- A `_build*` helper threading `theme`/`l10n`/a Cubit as parameters
  instead of reading them from `context` inside the method.
- Forgetting the empty state — `loaded` with zero items is a distinct,
  designed state, not something that falls through to the list widget
  rendering nothing.
- A hardcoded string anywhere in the widget tree, including `Semantics`
  labels and `tooltip`s.
- `setState` anywhere in a feature screen — state changes go through the
  Cubit/Bloc exclusively.

## Checklist

- [ ] Files live under `features/<feature>/{bloc,presentation/{,widgets/},models/}`.
- [ ] Public `XScreen` creates the Cubit; private `_XView` (or
      `_XContent`) consumes it via `BlocBuilder`.
- [ ] Every phase the state can be in (loading, empty, error, loaded) has
      an explicit, designed widget — nothing falls through by accident.
- [ ] No magic-number spacing, no raw `Color(0x...)`, no hand-built
      `TextStyle` — `AppSpacing`/`context.theme.colorScheme`/
      `context.theme.textTheme` used throughout.
- [ ] `context.theme`/`context.l10n` used, never `Theme.of`/
      `AppLocalizations.of` directly.
- [ ] Every `_build*` helper takes at most `BuildContext` plus genuinely
      non-derivable data, recursively.
- [ ] Interactive elements and meaningful icons have a localized
      `Semantics`/`tooltip` label.
- [ ] Any `AnimationController` that `repeat()`s is gated on
      `TickerMode.of(context)` if the screen can live inside a shell
      branch.
- [ ] A widget test exists for the new screen (see
      `.agents/skills/testing/SKILL.md`).
