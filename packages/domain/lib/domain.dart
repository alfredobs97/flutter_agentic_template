/// Public API of the `domain` package. Only top-level barrels are exported
/// here — never reach into `src/` from outside this package (AGENTS.md →
/// "Barrel files").
library;

export 'src/data_providers/data_providers.dart';
export 'src/entities/entities.dart';
export 'src/failures/failures.dart';
export 'src/repositories/repositories.dart';
