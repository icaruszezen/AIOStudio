import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class AioStudioApp extends ConsumerWidget {
  const AioStudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeNotifierProvider);

    return FluentApp.router(
      title: 'AIO Studio',
      themeMode: themeMode,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      locale: const Locale('zh', 'CN'),
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
