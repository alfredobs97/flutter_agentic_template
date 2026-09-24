/// A 4pt spacing scale, plus semantic aliases for the most common uses.
/// Never hardcode a `SizedBox`/`EdgeInsets` magic number — pick the closest
/// token here, or add a new semantic alias if a recurring need doesn't fit
/// one.
abstract final class AppSpacing {
  static const double hairline = 1;
  static const double space1 = 4;
  static const double space2 = 8;
  static const double space3 = 12;
  static const double space4 = 16;
  static const double space6 = 24;
  static const double space8 = 32;
  static const double space12 = 48;

  /// Horizontal padding for a screen's edge content.
  static const double pageMargin = space4;

  /// Default gap between two adjacent controls in a row/column.
  static const double gutter = space2;

  static const double stackSm = space2;
  static const double stackMd = space4;
  static const double stackLg = space6;

  static const double radiusSm = 4;
  static const double radiusMd = 8;
  static const double radiusLg = 16;
  static const double radiusFull = 999;
}
