import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

import '../../helpers/pump_app.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('renders the localized title and placeholder copy', (tester) async {
      await tester.pumpApp(const HomeScreen());

      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Run the new-feature skill to replace this screen.'), findsOneWidget);
    });

    testWidgets('title is rendered in the app bar', (tester) async {
      await tester.pumpApp(const HomeScreen());

      expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
    });
  });
}
