import 'package:fluent_ui/fluent_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../l10n/app_localizations.dart';

/// Centered error presentation with title, optional detail message, and optional retry action.
class ErrorState extends StatelessWidget {
  const ErrorState({
    super.key,
    required this.title,
    this.message,
    this.onRetry,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.error_badge,
              size: 48,
              color: AppColors.error(theme.brightness),
            ),
            const SizedBox(height: DesignTokens.spacingLG),
            Text(
              title,
              style: theme.typography.subtitle,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: DesignTokens.spacingSM),
              Text(
                message!,
                style: theme.typography.body?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
                textAlign: TextAlign.center,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: DesignTokens.spacingXL),
              Button(
                onPressed: onRetry,
                child: Text(S.of(context).actionRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
