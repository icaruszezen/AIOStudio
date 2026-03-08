import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'theme_mode';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden');
});

final themeNotifierProvider =
    NotifierProvider<ThemeNotifier, ThemeMode>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final value = prefs.getString(_themeModeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_themeModeKey, mode.name);
  }
}

class AppColors {
  AppColors._();

  // -- Feature / asset-type colors --

  static Color chat(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

  static Color imageGen(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6);

  static Color videoGen(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFEF4444);

  static Color audio(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF10B981);

  static Color textDoc(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

  static Color optimization(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF10B981);

  static Color neutral(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  // -- Status colors --

  static Color success(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF10B981);

  static Color error(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFF87171) : const Color(0xFFEF4444);

  static Color warning(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);

  static Color info(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

  static Color pending(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

  // -- Fixed semantic colors (identical in both modes) --

  static const Color favorite = Color(0xFFEF4444);

  // -- Overlay helpers (for content layered on images/video) --

  static Color overlayDark([double alpha = 0.5]) =>
      Colors.black.withValues(alpha: alpha);

  static Color overlayLight([double alpha = 0.9]) =>
      Colors.white.withValues(alpha: alpha);

  // -- Provider icon colors (settings page) --

  static Color providerOpenAI(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF34D399) : const Color(0xFF10B981);

  static Color providerGoogle(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6);

  static Color providerAnthropic(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B);

  static Color providerCustom(Brightness b) =>
      b == Brightness.dark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6);
}

class AppTheme {
  AppTheme._();

  static AccentColor? _cachedLightAccent;
  static FluentThemeData? _cachedLight;
  static AccentColor? _cachedDarkAccent;
  static FluentThemeData? _cachedDark;

  static Typography _typography(Brightness brightness) {
    const fontFamily = 'Microsoft YaHei UI';
    const fallback = ['PingFang SC', 'Noto Sans SC', 'sans-serif'];

    final color = brightness == Brightness.light
        ? const Color(0xE4000000)
        : Colors.white;

    TextStyle base(double size, FontWeight weight, double height) => TextStyle(
          fontFamily: fontFamily,
          fontFamilyFallback: fallback,
          fontSize: size,
          fontWeight: weight,
          height: height,
          color: color,
        );

    return Typography.raw(
      display: base(68, FontWeight.w600, 1.3),
      titleLarge: base(40, FontWeight.w600, 1.3),
      title: base(28, FontWeight.w600, 1.3),
      subtitle: base(20, FontWeight.w600, 1.35),
      bodyLarge: base(18, FontWeight.w400, 1.5),
      bodyStrong: base(14, FontWeight.w600, 1.5),
      body: base(14, FontWeight.w400, 1.5),
      caption: base(12, FontWeight.w400, 1.45),
    );
  }

  static FluentThemeData light([AccentColor? accent]) {
    final effective = accent ?? Colors.blue;
    if (_cachedLight != null && _cachedLightAccent == effective) {
      return _cachedLight!;
    }
    _cachedLightAccent = effective;
    _cachedLight = FluentThemeData(
      brightness: Brightness.light,
      accentColor: effective,
      visualDensity: VisualDensity.standard,
      typography: _typography(Brightness.light),
    );
    return _cachedLight!;
  }

  static FluentThemeData dark([AccentColor? accent]) {
    final effective = accent ?? Colors.blue;
    if (_cachedDark != null && _cachedDarkAccent == effective) {
      return _cachedDark!;
    }
    _cachedDarkAccent = effective;
    _cachedDark = FluentThemeData(
      brightness: Brightness.dark,
      accentColor: effective,
      visualDensity: VisualDensity.standard,
      typography: _typography(Brightness.dark),
    );
    return _cachedDark!;
  }
}
