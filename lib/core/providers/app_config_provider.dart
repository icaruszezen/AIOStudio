import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart' show sharedPreferencesProvider;

const _storageDirectoryKey = 'storage_directory';
const _extensionPortKey = 'extension_port';

/// Default TCP port for the browser extension bridge when none is saved.
const defaultExtensionPort = 52140;

// ---------------------------------------------------------------------------
// Storage directory (custom root for assets)
// ---------------------------------------------------------------------------

/// Holds the optional custom asset root path persisted in shared preferences.
final storageDirectoryProvider =
    NotifierProvider<StorageDirectoryNotifier, String?>(
      StorageDirectoryNotifier.new,
    );

/// Loads and updates the custom storage directory setting.
class StorageDirectoryNotifier extends Notifier<String?> {
  /// Reads the saved path from shared preferences, or null if unset.
  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getString(_storageDirectoryKey);
  }

  /// Persists [path] (or clears it when null) and updates notifier state.
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
// Browser extension communication port
// ---------------------------------------------------------------------------

/// Holds the extension HTTP port persisted in shared preferences.
final extensionPortProvider = NotifierProvider<ExtensionPortNotifier, int>(
  ExtensionPortNotifier.new,
);

/// Loads and updates the browser extension communication port.
class ExtensionPortNotifier extends Notifier<int> {
  /// Returns the saved port or [defaultExtensionPort] if none is stored.
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getInt(_extensionPortKey) ?? defaultExtensionPort;
  }

  /// Persists [port] to shared preferences and updates notifier state.
  Future<void> setPort(int port) async {
    state = port;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_extensionPortKey, port);
  }
}
