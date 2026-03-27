import 'package:fluent_ui/fluent_ui.dart';

import '../../core/theme/design_tokens.dart';

/// Placeholder when a list or view has no data: icon, title, optional description and action.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacingXXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.resources.textFillColorSecondary),
            const SizedBox(height: DesignTokens.spacingLG),
            Text(
              title,
              style: theme.typography.subtitle,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: DesignTokens.spacingSM),
              Text(
                description!,
                style: theme.typography.body?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: DesignTokens.spacingXL),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
