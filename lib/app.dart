import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ui/ui.dart';

/// The root widget: `MultiRepositoryProvider` → `MultiBlocProvider` →
/// `MaterialApp.router`.
///
/// Every repository built in `bootstrap.dart` is passed in here as a named
/// parameter and exposed via `RepositoryProvider.value` — this is the only
/// dependency-injection mechanism in the app (no `get_it`/service locator;
/// see AGENTS.md → "State management & dependency injection"). Add a
/// parameter and a matching `RepositoryProvider.value` entry for every new
/// repository.
class App extends StatelessWidget {
  const App({
    required this.router,
    required this.featureFlagRepository,
    super.key,
  });

  /// Built once in `bootstrap.dart` via `buildAppRouter()` and passed down,
  /// rather than called again here — `build()` can run more than once, and
  /// `app_router.dart` explicitly forbids memoizing it as a top-level
  /// singleton, so the composition root is where it's built exactly once.
  final GoRouter router;
  final FeatureFlagRepository featureFlagRepository;

  @override
  Widget build(BuildContext context) => MultiRepositoryProvider(
    providers: [
      RepositoryProvider<FeatureFlagRepository>.value(value: featureFlagRepository),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => FeatureFlagCubit(context.read<FeatureFlagRepository>()),
        ),
      ],
      child: MaterialApp.router(
        onGenerateTitle: (context) => context.l10n.appTitle,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // ThemeMode.system is MaterialApp's default; left off here only
        // because very_good_analysis's avoid_redundant_argument_values
        // flags a value that matches the default — the app still follows
        // the OS light/dark setting.
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    ),
  );
}
