import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

void main() {
  Future<void> pumpRouter(WidgetTester tester) {
    // A fresh router per test, per the "function, not a singleton" rule in
    // app_router.dart — this is exactly why that rule exists: no shared
    // navigation state can leak between tests.
    final router = buildAppRouter();
    return tester.pumpWidget(
      RepositoryProvider<FeatureFlagRepository>.value(
        value: const FeatureFlagRepository(FeatureFlags({})),
        child: BlocProvider(
          create: (context) => FeatureFlagCubit(context.read<FeatureFlagRepository>()),
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      ),
    );
  }

  group('buildAppRouter', () {
    testWidgets('starts at the home route', (tester) async {
      await pumpRouter(tester);
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('shows RouteErrorScreen for an unknown location', (tester) async {
      final router = buildAppRouter();
      await tester.pumpWidget(
        RepositoryProvider<FeatureFlagRepository>.value(
          value: const FeatureFlagRepository(FeatureFlags({})),
          child: BlocProvider(
            create: (context) => FeatureFlagCubit(context.read<FeatureFlagRepository>()),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      router.go('/does-not-exist');
      await tester.pumpAndSettle();

      expect(find.byType(RouteErrorScreen), findsOneWidget);
    });
  });
}
