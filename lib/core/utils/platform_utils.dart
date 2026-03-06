import 'package:flutter/foundation.dart';

/// Centralised platform detection helpers.
abstract final class PlatformUtils {
  static bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static bool get isMobile =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  static bool get isWeb => kIsWeb;
}

/// Responsive width breakpoints used across the app.
abstract final class Breakpoints {
  /// Tablets and narrow desktop windows.
  static const double tablet = 800.0;
}
