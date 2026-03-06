import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart' show sharedPreferencesProvider;

const _accentColorKey = 'accent_color';
const _localeKey = 'locale';
const _storageDirectoryKey = 'storage_directory';
const _autoSaveChatKey = 'auto_save_chat';
const _extensionPortKey = 'extension_port';

const defaultExtensionPort = 52140;

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
    state = color;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_accentColorKey, _accentColorName(color));
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
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_localeKey, locale.toLanguageTag());
  }
}

// ---------------------------------------------------------------------------
// Storage directory (custom root for assets)
// ---------------------------------------------------------------------------

final storageDirectoryProvider =
    NotifierProvider<StorageDirectoryNotifier, String?>(
        StorageDirectoryNotifier.new);

class StorageDirectoryNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_storageDirectoryKey);
  }

  Future<void> setDirectory(String? path) async {
    state = path;
    final prefs = ref.read(sharedPreferencesProvider);
    if (path == null) {
      await prefs.remove(_storageDirectoryKey);
    } else {
      await prefs.setString(_storageDirectoryKey, path);
    }
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
    state = !state;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_autoSaveChatKey, state);
  }
}

// ---------------------------------------------------------------------------
// Browser extension communication port
// ---------------------------------------------------------------------------

final extensionPortProvider =
    NotifierProvider<ExtensionPortNotifier, int>(ExtensionPortNotifier.new);

class ExtensionPortNotifier extends Notifier<int> {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(_extensionPortKey) ?? defaultExtensionPort;
  }

  Future<void> setPort(int port) async {
    state = port;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_extensionPortKey, port);
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
