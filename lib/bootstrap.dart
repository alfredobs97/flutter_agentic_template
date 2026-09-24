import 'dart:async';
import 'dart:developer' as developer;

import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:ui/ui.dart';

import 'app.dart';
import 'app_environment.dart';
import 'feature_flag_defaults.dart';

/// Wires the composition root and runs the app.
///
/// This is the **only** place in the codebase allowed to import both
/// `data` and `ui` — see AGENTS.md → "Dependency rule". Every repository
/// is instantiated exactly once here and handed down through
/// `RepositoryProvider`; nothing below this function ever constructs one
/// itself.
///
/// Called from `lib/main.dart`, which stays a two-line entrypoint so a
/// flavor-specific `main_dev.dart`/`main_prod.dart` (if you ever need one
/// instead of `--dart-define=FLAVOR`) can call straight into this.
void bootstrap() {
  runZonedGuarded(
    () {
      WidgetsFlutterBinding.ensureInitialized();
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        _reportUncaughtError(details.exception, details.stack ?? StackTrace.current);
      };

      // --- Composition root -------------------------------------------------
      // Add your chosen data-stack's client/database here (see
      // `.agents/skills/choose-data-stack/SKILL.md`), then a concrete data
      // provider for each `domain` interface, then the repository that
      // wraps it. Example, once a Tasks feature exists:
      //
      //   final database = AppDatabase();
      //   final taskDataProvider = DriftTaskDataProvider(database);
      //   final taskRepository = TaskRepository(dataProvider: taskDataProvider);
      final featureFlagRepository = FeatureFlagRepository(
        FeatureFlags(featureFlagDefaultsFor(AppEnvironment.flavor)),
      );

      runApp(
        App(
          router: buildAppRouter(),
          featureFlagRepository: featureFlagRepository,
          // Add every further repository here as a named parameter and
          // thread it into App's MultiRepositoryProvider (lib/app.dart).
        ),
      );
    },
    _reportUncaughtError,
  );
}

/// The single seam every uncaught error and Flutter framework error flows
/// through. Logs locally by default; replace the `developer.log` call with
/// your crash-reporting SDK (Crashlytics, Sentry, ...) — see
/// `.agents/skills/choose-data-stack/SKILL.md` for wiring one in alongside
/// your data stack.
void _reportUncaughtError(Object error, StackTrace stack) {
  developer.log('Uncaught error', error: error, stackTrace: stack, level: 1000);
}
