import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

import '../../database/app_database.dart';
import '../../providers/database_provider.dart';
import '../../../features/settings/providers/settings_provider.dart';
import 'extension_server.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

// ---------------------------------------------------------------------------
// Extension Server instance
// ---------------------------------------------------------------------------

final extensionServerInstanceProvider = Provider<ExtensionServer>((ref) {
  final server = ExtensionServer(
    projectDao: ref.read(projectDaoProvider),
    assetDao: ref.read(assetDaoProvider),
    tagDao: ref.read(tagDaoProvider),
    fileManager: ref.read(assetFileManagerProvider),
  );
  ref.onDispose(() => server.dispose());
  return server;
});

// ---------------------------------------------------------------------------
// Server lifecycle (start / stop / restart)
// ---------------------------------------------------------------------------

final extensionServerProvider =
    AsyncNotifierProvider<ExtensionServerNotifier, bool>(
        ExtensionServerNotifier.new);

class ExtensionServerNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    ref.onDispose(() => _healthTimer?.cancel());
    final server = ref.watch(extensionServerInstanceProvider);
    final port = ref.read(extensionPortProvider);
    try {
      final actualPort = await server.start(port);
      ref.read(extensionActualPortProvider.notifier).setPort(actualPort);
      _startHealthPolling();
      return true;
    } catch (e, st) {
      _log.e('Failed to start extension server', error: e, stackTrace: st);
      return false;
    }
  }

  Future<void> restart() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final server = ref.read(extensionServerInstanceProvider);
      final port = ref.read(extensionPortProvider);
      final actualPort = await server.restart(port);
      ref.read(extensionActualPortProvider.notifier).setPort(actualPort);
      _startHealthPolling();
      return true;
    });
  }

  Future<void> stopServer() async {
    final server = ref.read(extensionServerInstanceProvider);
    await server.stop();
    _healthTimer?.cancel();
    ref.read(extensionConnectionStatusProvider.notifier).setConnected(false);
    state = const AsyncValue.data(false);
  }

  Future<void> startServer() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final server = ref.read(extensionServerInstanceProvider);
      final port = ref.read(extensionPortProvider);
      final actualPort = await server.start(port);
      ref.read(extensionActualPortProvider.notifier).setPort(actualPort);
      _startHealthPolling();
      return true;
    });
  }

  Timer? _healthTimer;

  void _startHealthPolling() {
    _healthTimer?.cancel();
    _healthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      final server = ref.read(extensionServerInstanceProvider);
      final lastPing = server.lastHealthPing;
      final connected = lastPing != null &&
          DateTime.now().difference(lastPing).inSeconds < 30;
      ref
          .read(extensionConnectionStatusProvider.notifier)
          .setConnected(connected);
    });
  }
}

// ---------------------------------------------------------------------------
// Connection status – true when extension has pinged within last 30 s
// ---------------------------------------------------------------------------

final extensionConnectionStatusProvider =
    NotifierProvider<ExtensionConnectionStatusNotifier, bool>(
        ExtensionConnectionStatusNotifier.new);

class ExtensionConnectionStatusNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setConnected(bool value) => state = value;
}

// ---------------------------------------------------------------------------
// Actual port (may differ from config if the preferred port was in use)
// ---------------------------------------------------------------------------

final extensionActualPortProvider =
    NotifierProvider<ExtensionActualPortNotifier, int>(
        ExtensionActualPortNotifier.new);

class ExtensionActualPortNotifier extends Notifier<int> {
  @override
  int build() => ref.watch(extensionPortProvider);

  void setPort(int port) => state = port;
}

// ---------------------------------------------------------------------------
// Import event stream – UI subscribes to show notifications
// ---------------------------------------------------------------------------

final extensionImportStreamProvider = StreamProvider<Asset>((ref) {
  final server = ref.watch(extensionServerInstanceProvider);
  return server.importStream;
});
