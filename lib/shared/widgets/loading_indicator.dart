import 'package:fluent_ui/fluent_ui.dart';

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
            const SizedBox(height: 16),
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
