import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_theme.dart' show sharedPreferencesProvider;
import '../../../core/utils/platform_utils.dart';

export '../../../core/providers/app_config_provider.dart'
    show
        storageDirectoryProvider,
        extensionPortProvider,
        defaultExtensionPort;

const _accentColorKey = 'accent_color';
const _localeKey = 'locale';
const _autoSaveChatKey = 'auto_save_chat';
const _windowEffectKey = 'window_effect';
const _githubMirrorKey = 'github_mirror';

const githubBaseUrl = 'https://github.com/icaruszezen/AIOStudio';

const kCustomMirrorValue = '__custom__';

const githubMirrors = <String, String>{
  '': '直连（不加速）',
  'https://ghgo.xyz/': 'GHGO (ghgo.xyz)',
  'https://mirror.ghproxy.com/': 'GHProxy Mirror',
  'https://gh-proxy.com/': 'GH Proxy',
};

/// Prepend [mirrorPrefix] to accelerate file downloads from GitHub.
/// Only use for actual file URLs, NOT for page URLs (releases page, repo page, etc.).
String resolveGithubUrl(String fileUrl, String mirrorPrefix) {
  if (mirrorPrefix.isEmpty) return fileUrl;
  return '$mirrorPrefix$fileUrl';
}

/// Build the GitHub Releases asset download URL for a given [version] and [assetName].
/// Example: `https://github.com/.../releases/download/v1.0.4/aio-studio-extension-v1.0.4.zip`
String githubReleaseAssetUrl(String version, String assetName) {
  return '$githubBaseUrl/releases/download/v$version/$assetName';
}

String extensionAssetName(String version) =>
    'aio-studio-extension-v$version.zip';

// ---------------------------------------------------------------------------
// Accent Color
// ---------------------------------------------------------------------------

final accentColorProvider =
    NotifierProvider<AccentColorNotifier, AccentColor>(AccentColorNotifier.new);

class AccentColorNotifier extends Notifier<AccentColor> {
  @override
  AccentColor build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final name = prefs.getString(_accentColorKey);
    return _accentColorFromName(name) ?? Colors.blue;
  }

  Future<void> setAccentColor(AccentColor color) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_accentColorKey, _accentColorName(color));
    state = color;
  }
}

// ---------------------------------------------------------------------------
// Locale
// ---------------------------------------------------------------------------

final localeProvider =
    NotifierProvider<LocaleNotifier, Locale>(LocaleNotifier.new);

class LocaleNotifier extends Notifier<Locale> {
  @override
  Locale build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final tag = prefs.getString(_localeKey);
    return switch (tag) {
      'en' => const Locale('en'),
      _ => const Locale('zh', 'CN'),
    };
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_localeKey, locale.toLanguageTag());
    state = locale;
  }
}

// ---------------------------------------------------------------------------
// Auto-save chat history
// ---------------------------------------------------------------------------

final autoSaveChatProvider =
    NotifierProvider<AutoSaveChatNotifier, bool>(AutoSaveChatNotifier.new);

class AutoSaveChatNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_autoSaveChatKey) ?? true;
  }

  Future<void> toggle() async {
    final newValue = !state;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_autoSaveChatKey, newValue);
    state = newValue;
  }
}

// ---------------------------------------------------------------------------
// Window effect preference
// ---------------------------------------------------------------------------

enum AppWindowEffect { none, acrylic, mica, tabbed }

/// Maps [AppWindowEffect] to [WindowEffect] from flutter_acrylic,
/// with platform-specific degradation (macOS: no mica/tabbed; Linux: transparent only).
WindowEffect resolveWindowEffect(AppWindowEffect effect) {
  if (!PlatformUtils.isDesktop) return WindowEffect.disabled;
  if (defaultTargetPlatform == TargetPlatform.linux) {
    return effect == AppWindowEffect.none
        ? WindowEffect.disabled
        : WindowEffect.transparent;
  }
  return switch (effect) {
    AppWindowEffect.none => WindowEffect.disabled,
    AppWindowEffect.acrylic => WindowEffect.acrylic,
    AppWindowEffect.mica => defaultTargetPlatform == TargetPlatform.windows
        ? WindowEffect.mica
        : WindowEffect.acrylic,
    AppWindowEffect.tabbed => defaultTargetPlatform == TargetPlatform.windows
        ? WindowEffect.tabbed
        : WindowEffect.acrylic,
  };
}

/// Read the persisted window effect from [prefs] without Riverpod.
/// Used in [main] before the provider container is created.
AppWindowEffect readSavedWindowEffect(SharedPreferences prefs) {
  final value = prefs.getString(_windowEffectKey);
  return AppWindowEffect.values.firstWhere(
    (e) => e.name == value,
    orElse: () => AppWindowEffect.acrylic,
  );
}

final windowEffectProvider =
    NotifierProvider<WindowEffectNotifier, AppWindowEffect>(
        WindowEffectNotifier.new);

class WindowEffectNotifier extends Notifier<AppWindowEffect> {
  @override
  AppWindowEffect build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final value = prefs.getString(_windowEffectKey);
    return AppWindowEffect.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AppWindowEffect.acrylic,
    );
  }

  Future<void> setEffect(AppWindowEffect effect) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_windowEffectKey, effect.name);
    if (PlatformUtils.isDesktop) {
      await Window.setEffect(
        effect: resolveWindowEffect(effect),
        color: const Color(0x00000000),
      );
    }
    state = effect;
  }
}

// ---------------------------------------------------------------------------
// GitHub mirror / acceleration
// ---------------------------------------------------------------------------

final githubMirrorProvider =
    NotifierProvider<GithubMirrorNotifier, String>(GithubMirrorNotifier.new);

class GithubMirrorNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_githubMirrorKey) ?? '';
  }

  Future<void> setMirror(String prefix) async {
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefix.isEmpty) {
      await prefs.remove(_githubMirrorKey);
    } else {
      await prefs.setString(_githubMirrorKey, prefix);
    }
    state = prefix;
  }
}

// ---------------------------------------------------------------------------
// Helpers – AccentColor <-> String mapping
// ---------------------------------------------------------------------------

final _accentColorMap = <String, AccentColor>{
  'yellow': Colors.yellow,
  'orange': Colors.orange,
  'red': Colors.red,
  'magenta': Colors.magenta,
  'purple': Colors.purple,
  'blue': Colors.blue,
  'teal': Colors.teal,
  'green': Colors.green,
};

AccentColor? _accentColorFromName(String? name) => _accentColorMap[name];

String _accentColorName(AccentColor color) {
  for (final entry in _accentColorMap.entries) {
    if (entry.value == color) return entry.key;
  }
  return 'blue';
}

final availableAccentColors = _accentColorMap.values.toList();
