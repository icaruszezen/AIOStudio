import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/providers/database_provider.dart';
import 'core/services/extension_bridge/extension_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/platform_utils.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 4));

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    MediaKit.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      _log.e(
        'FlutterError',
        error: details.exception,
        stackTrace: details.stack,
      );
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      _log.e('PlatformDispatcher error', error: error, stackTrace: stack);
      return true;
    };

    PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20;

    if (PlatformUtils.isDesktop) {
      await windowManager.ensureInitialized();

      await Window.initialize();
      await Window.setEffect(
        effect: defaultTargetPlatform == TargetPlatform.linux
            ? WindowEffect.transparent
            : WindowEffect.acrylic,
        color: const Color(0x00000000),
      );

      const windowOptions = WindowOptions(
        size: Size(1280, 800),
        minimumSize: Size(900, 600),
        center: true,
        titleBarStyle: TitleBarStyle.hidden,
        title: 'AIO Studio',
      );

      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    final prefs = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );

    final secureKeys = container.read(secureKeyServiceProvider);
    final dao = container.read(aiProviderConfigDaoProvider);
    await secureKeys.migrateFromDatabase(dao);

    if (PlatformUtils.isDesktop) {
      container.read(extensionServerProvider);
    }

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const AioStudioApp(),
      ),
    );
  }, (error, stack) {
    _log.e('Uncaught async error', error: error, stackTrace: stack);
  });
}

