import 'package:domain/domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_agentic_template/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

/// End-to-end check that the composition root, router and RouteErrorScreen
/// are wired together correctly — complements test/app_test.dart, which
/// only checks the initial render.
void main() {
  testWidgets('App recovers from an unknown route via RouteErrorScreen', (tester) async {
    final router = buildAppRouter();
    await tester.pumpWidget(
      App(
        router: router,
        featureFlagRepository: const FeatureFlagRepository(FeatureFlags({})),
      ),
    );
    await tester.pumpAndSettle();

    router.go('/does-not-exist');
    await tester.pumpAndSettle();
    expect(find.byType(RouteErrorScreen), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
  });
}
