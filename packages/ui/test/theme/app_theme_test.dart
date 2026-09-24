import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/ui.dart';

void main() {
  group('AppTheme', () {
    test('light and dark themes use their matching brightness', () {
      expect(AppTheme.light.brightness, Brightness.light);
      expect(AppTheme.dark.brightness, Brightness.dark);
    });

    test('light and dark themes share the same seed-derived primary hue', () {
      expect(AppTheme.light.colorScheme.primary, AppColors.lightScheme.primary);
      expect(AppTheme.dark.colorScheme.primary, AppColors.darkScheme.primary);
    });
  });
}
