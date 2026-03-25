import 'package:fluent_ui/fluent_ui.dart';

import '../../core/theme/design_tokens.dart';

/// Centered progress ring for async or loading UI, with an optional status message.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
  });

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const ProgressRing(),
          if (message != null) ...[
            const SizedBox(height: DesignTokens.spacingLG),
            Text(
              message!,
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
