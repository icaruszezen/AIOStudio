import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      content: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.error_badge,
              size: 64,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(height: 16),
            Text('页面不存在', style: theme.typography.title),
            const SizedBox(height: 8),
            Text(
              '你访问的页面不存在或已被移除',
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go(AppRoutes.projects),
              child: const Text('返回首页'),
            ),
          ],
        ),
      ),
    );
  }
}
