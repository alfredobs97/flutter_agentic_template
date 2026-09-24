# `ui` — layer rules

See the root `AGENTS.md` first — this file only adds detail specific to
this package.

## What belongs here

- **`features/<feature>/`**: `bloc/`, `presentation/` (screens plus
  `widgets/`), optionally `models/`. See `features/home/` for the
  `presentation/` half of the pattern worked out in full, and
  `.agents/skills/new-feature/SKILL.md` for the Cubit half.
- **`app_blocs/`**: Cubits/BLoCs provided once, above `MaterialApp.router`
  in `lib/app.dart` at the app root (e.g. `FeatureFlagCubit`) — as opposed
  to a screen-scoped Cubit created inside that screen's own `build`.
- **`common_widgets/`**: a widget reused by two or more features. Check
  here — and check whether a plain Material widget already covers the
  need — before writing a new one. Promote a widget here only once a
  *second* feature needs it (don't pre-emptively move it — YAGNI).
- **`theme/`**: design tokens (`AppColors`, `AppSpacing`, `AppTypography`,
  `AppTheme`) and the `BuildContextX` extension. See root `AGENTS.md`
  section 15.
- **`router/`**: `buildAppRouter()` and `RouteErrorScreen`. See root
  `AGENTS.md` section 10.
- **`l10n/`**: ARB source files. Generated output lands in `src/l10n/` —
  never hand-edit it.
- **`preview/`**: `appPreviewWrapper`, for previewing a widget without
  booting the full app.

## What does NOT belong here

- **Any import of `package:data`.** This is the one rule in this codebase
  with zero exceptions. If a screen needs data, it goes through a
  repository (from `domain`) injected into a Cubit/BLoC — never a data
  provider directly, and never `data` itself.
- `setState` in a feature screen — Cubit/BLoC only (root `AGENTS.md`
  section 3).
- A hardcoded user-facing string (root `AGENTS.md` section 11).

## Testing

`flutter_test`, `bloc_test`, `mocktail`. Use `test/helpers/pump_app.dart`'s
`pumpApp` extension for a widget test instead of re-declaring the provider
wiring per file. A Cubit/BLoC test mocks the `domain` repository it depends
on with `mocktail` (`class MockXRepository extends Mock implements
XRepository {}`) — never the data provider underneath it.
