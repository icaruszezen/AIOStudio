import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/database/app_database.dart';
import 'core/services/extension_bridge/extension_providers.dart';
import 'core/services/notification_service.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/providers/settings_provider.dart';

class AioStudioApp extends ConsumerStatefulWidget {
  const AioStudioApp({super.key});

  @override
  ConsumerState<AioStudioApp> createState() => _AioStudioAppState();
}

class _AioStudioAppState extends ConsumerState<AioStudioApp> {
  ProviderSubscription<AsyncValue<Asset>>? _importSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _listenExtensionImports();
    });
  }

  @override
  void dispose() {
    _importSub?.close();
    super.dispose();
  }

  void _listenExtensionImports() {
    _importSub = ref.listenManual(extensionImportStreamProvider, (prev, next) {
      final asset = next.value;
      if (asset == null) return;

      final navContext = NotificationService.navigatorKey.currentContext;
      if (navContext == null) return;

      final router = ref.read(appRouterProvider);

      displayInfoBar(navContext, builder: (ctx, close) {
        return InfoBar(
          title: Text('已从浏览器保存：${asset.name}'),
          severity: InfoBarSeverity.success,
          action: Button(
            onPressed: () {
              close();
              router.go('/assets/${asset.id}');
            },
            child: const Text('查看'),
          ),
          onClose: close,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeNotifierProvider);
    final accentColor = ref.watch(accentColorProvider);
    final locale = ref.watch(localeProvider);

    return FluentApp.router(
      title: 'AIO Studio',
      themeMode: themeMode,
      theme: AppTheme.light(accentColor),
      darkTheme: AppTheme.dark(accentColor),
      locale: locale,
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        FluentLocalizations.delegate,
      ],
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
