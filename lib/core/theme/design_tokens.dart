import 'package:fluent_ui/fluent_ui.dart';

/// Unified design tokens for spacing, border radius, and icon sizes.
///
/// These constants follow Fluent Design guidelines and should be used
/// throughout the app instead of hard-coded literal values.
abstract final class DesignTokens {
  // -- Spacing --
  static const double spacingXS = 4;
  static const double spacingSM = 8;
  static const double spacingMD = 12;
  static const double spacingLG = 16;
  static const double spacingXL = 24;
  static const double spacingXXL = 32;

  // -- Border Radius --
  static const double radiusSM = 4;
  static const double radiusMD = 6;
  static const double radiusLG = 8;
  static const double radiusXL = 12;

  // -- Icon Size --
  static const double iconXS = 12;
  static const double iconSM = 14;
  static const double iconMD = 16;
  static const double iconLG = 20;
  static const double iconXL = 24;

  // -- Font families --
  static const String fontFamily = 'Microsoft YaHei UI';
  static const List<String> fontFallback = [
    'PingFang SC',
    'Noto Sans SC',
    'sans-serif',
  ];
  static const String monoFontFamily = 'Consolas';
  static const List<String> monoFontFallback = [
    'Menlo',
    'Monaco',
    'Courier New',
    'monospace',
  ];

  // -- Convenience BorderRadius values --
  static final BorderRadius borderRadiusSM = BorderRadius.circular(radiusSM);
  static final BorderRadius borderRadiusMD = BorderRadius.circular(radiusMD);
  static final BorderRadius borderRadiusLG = BorderRadius.circular(radiusLG);
  static final BorderRadius borderRadiusXL = BorderRadius.circular(radiusXL);
}
