import 'dart:async';
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:uuid/uuid.dart';

import '../../database/app_database.dart';
import '../storage/asset_file_manager.dart';
import 'extension_handlers.dart';
import 'extension_middleware.dart';

const _maxPortRetries = 10;

class ExtensionServer {
  HttpServer? _server;
  late final ExtensionHandlers _handlers;
  final StreamController<Asset> _importController =
      StreamController<Asset>.broadcast();

  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));

  /// Random token generated once per server instance, required in the
  /// `Authorization: Bearer <token>` header for all non-health requests.
  final String authToken = const Uuid().v4();

  bool get isRunning => _server != null;
  int? get actualPort => _server?.port;
  Stream<Asset> get importStream => _importController.stream;
  DateTime? get lastHealthPing => _handlers.lastHealthPing;

  ExtensionServer({
    required ProjectDao projectDao,
    required AssetDao assetDao,
    required TagDao tagDao,
    required AssetFileManager fileManager,
  }) {
    _handlers = ExtensionHandlers(
      projectDao: projectDao,
      assetDao: assetDao,
      tagDao: tagDao,
      fileManager: fileManager,
      importEventController: _importController,
    );
  }

  /// Starts the HTTP server on [port], retrying up to [_maxPortRetries]
  /// times with incrementing ports if the address is already in use.
  /// Returns the actual port the server is listening on.
  Future<int> start(int port) async {
    if (_server != null) {
      _log.w('Server already running on port ${_server!.port}');
      return _server!.port;
    }

    final pipeline = const shelf.Pipeline()
        .addMiddleware(corsMiddleware())
        .addMiddleware(originCheckMiddleware())
        .addMiddleware(tokenAuthMiddleware(authToken))
        .addMiddleware(requestSizeLimitMiddleware())
        .addMiddleware(rateLimitMiddleware())
        .addMiddleware(shelf.logRequests())
        .addHandler(_handlers.router.call);

    for (var attempt = 0; attempt < _maxPortRetries; attempt++) {
      final tryPort = port + attempt;
      try {
        _server = await shelf_io.serve(
          pipeline,
          InternetAddress.loopbackIPv4,
          tryPort,
        );
        _log.i('Extension server started on http://127.0.0.1:$tryPort');
        return tryPort;
      } on SocketException catch (e) {
        _log.w('Port $tryPort in use, trying next... ($e)');
        if (attempt == _maxPortRetries - 1) {
          throw SocketException(
              'Failed to bind after $_maxPortRetries attempts starting from port $port');
        }
      }
    }

    throw StateError('Unreachable');
  }

  Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _log.i('Extension server stopped');
      _server = null;
    }
  }

  Future<int> restart(int port) async {
    await stop();
    return start(port);
  }

  Future<void> dispose() async {
    await stop();
    await _importController.close();
  }
}
