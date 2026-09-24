/// Barrel for `features/` — one subfolder per feature (e.g. `tasks/`,
/// `profile/`), each with its own `bloc/`, `presentation/` (screens plus a
/// `widgets/` subfolder for screen-local widgets), and optionally
/// `models/` for UI-only value types (form drafts, navigation arguments).
/// See `.agents/skills/new-feature/SKILL.md` and `home/` for a worked
/// example of the `presentation/` half of that layout.
///
/// Export every feature's own barrel (`<feature>.dart`) from this file.
library;

export 'home/home.dart';
