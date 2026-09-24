/// Barrel for `common_widgets/` — currently empty by design.
///
/// A common widget is a small, presentation-only building block reused by
/// two or more features (a top app bar, a segmented control, an empty-state
/// illustration, ...). Before building a custom widget for a new screen,
/// check here first — and check whether an existing Material widget already
/// covers the need (see the `ponytail`-style guidance in AGENTS.md).
///
/// A widget belongs here, not inside a single feature's `widgets/` folder,
/// once a second feature needs it — don't pre-emptively move it before
/// that happens (YAGNI).
///
/// Export every widget file added under `common_widgets/` from this
/// barrel.
library;
