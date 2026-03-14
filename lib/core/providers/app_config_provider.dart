import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/app_theme.dart' show sharedPreferencesProvider;

const _storageDirectoryKey = 'storage_directory';
const _extensionPortKey = 'extension_port';
const defaultExtensionPort = 52140;

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
