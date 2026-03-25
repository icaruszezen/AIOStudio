import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';

/// Full-page 404 UI shown for unknown routes, with navigation back to the app home.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final l = S.of(context);

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
            const SizedBox(height: DesignTokens.spacingLG),
            Text(l.pageNotFoundTitle, style: theme.typography.title),
            const SizedBox(height: DesignTokens.spacingSM),
            Text(
              l.pageNotFoundDescription,
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const SizedBox(height: DesignTokens.spacingXL),
            FilledButton(
              onPressed: () => context.go(AppRoutes.projects),
              child: Text(l.pageNotFoundAction),
            ),
          ],
        ),
      ),
    );
  }
}
