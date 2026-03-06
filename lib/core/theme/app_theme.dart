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

class AppTheme {
  AppTheme._();

  static AccentColor? _cachedLightAccent;
  static FluentThemeData? _cachedLight;
  static AccentColor? _cachedDarkAccent;
  static FluentThemeData? _cachedDark;

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
    );
    return _cachedDark!;
  }
}
