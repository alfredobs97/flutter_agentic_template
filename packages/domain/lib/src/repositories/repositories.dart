/// Barrel for `repositories/`.
///
/// A repository is a **concrete class**, not an interface — this codebase
/// does not use the repository-interface pattern or use cases. It depends
/// on one or more `data_provider` interfaces (constructor-injected) and
/// contains the orchestration a use case would normally hold: combining
/// several data providers, applying a domain rule before persisting,
/// exposing a `watchX()` stream built from a provider's stream.
///
/// A repository is instantiated exactly once, in the composition root
/// (`lib/main.dart` at the app root), and handed to the widget tree via
/// `RepositoryProvider<TaskRepository>.value(...)`. `ui` Cubits/BLoCs
/// receive it through their constructor, obtained with
/// `context.read<TaskRepository>()` — never instantiated inside a widget.
///
/// See `.agents/skills/new-feature/SKILL.md` for the end-to-end template
/// (entity → data provider interface → repository → Drift/Dio/etc.
/// implementation → composition root → Cubit → screen).
///
/// Export every repository file added under `repositories/` from this
/// barrel.
library;

export 'feature_flag_repository.dart';
