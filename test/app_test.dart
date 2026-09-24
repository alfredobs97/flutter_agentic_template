import 'package:domain/domain.dart';
import 'package:flutter_agentic_template/app.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

void main() {
  group('App', () {
    testWidgets('renders the home screen at startup', (tester) async {
      await tester.pumpWidget(
        App(
          router: buildAppRouter(),
          featureFlagRepository: const FeatureFlagRepository(FeatureFlags({})),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
