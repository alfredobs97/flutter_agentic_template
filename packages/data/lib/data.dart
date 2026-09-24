/// Public API of the `data` package. Only top-level barrels are exported
/// here — never reach into `src/` from outside this package. `ui` MUST
/// NEVER import this package at all (AGENTS.md → "Dependency rule"); only
/// the composition root (`lib/main.dart` at the app root) does.
library;

export 'src/data_providers/data_providers.dart';
export 'src/guards/failure_guard.dart';
