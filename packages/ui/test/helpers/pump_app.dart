import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

/// Shared widget-test bootstrap: wires the app-wide providers every screen
/// expects (`FeatureFlagRepository` + `FeatureFlagCubit`) and the theme/
/// localization delegates, without booting the real router.
///
/// Add a new pumper here (e.g. `pumpAppRouted`) instead of redeclaring
/// this wiring inside individual test files — see AGENTS.md → "Testing".
extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget, {FeatureFlagRepository? featureFlagRepository}) {
    return pumpWidget(
      RepositoryProvider<FeatureFlagRepository>.value(
        value: featureFlagRepository ?? const FeatureFlagRepository(FeatureFlags({})),
        child: BlocProvider(
          create: (context) => FeatureFlagCubit(context.read<FeatureFlagRepository>()),
          child: MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: widget,
          ),
        ),
      ),
    );
  }
}
