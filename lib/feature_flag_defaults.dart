import 'package:domain/domain.dart';

import 'app_environment.dart';

/// The default value of every [FeatureFlag] for a given [AppFlavor].
///
/// Called once from `_bootstrap()` in `lib/main.dart` to build the
/// [FeatureFlagRepository]. A flag can default to `true` in `dev` and
/// `false` in `prod` while a feature is being finished — see
/// `.agents/skills/flavors-and-flags/SKILL.md`.
Map<FeatureFlag, bool> featureFlagDefaultsFor(AppFlavor flavor) => switch (flavor) {
  AppFlavor.dev => {FeatureFlag.exampleFeature: true},
  AppFlavor.prod => {FeatureFlag.exampleFeature: false},
};
