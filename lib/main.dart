import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/providers/database_provider.dart';
import 'core/services/extension_bridge/extension_providers.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/platform_utils.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSizeBytes = 100 << 20; // 100 MB

  if (PlatformUtils.isDesktop) {
    await windowManager.ensureInitialized();

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
}

