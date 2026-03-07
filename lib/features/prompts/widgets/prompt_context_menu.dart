import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';

void showPromptContextMenu({
  required BuildContext context,
  required FlyoutController controller,
  required Offset position,
  required Prompt prompt,
  VoidCallback? onFavoriteToggle,
  VoidCallback? onDelete,
  VoidCallback? onDuplicate,
  VoidCallback? onCopyContent,
}) {
  controller.showFlyout(
    navigatorKey: Navigator.of(context, rootNavigator: true),
    position: position,
    barrierDismissible: true,
    builder: (ctx) {
      return MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.copy),
            text: const Text('复制内容'),
            onPressed: () {
              Flyout.of(ctx).close();
              onCopyContent?.call();
            },
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.document_reply),
            text: const Text('复制为新提示词'),
            onPressed: () {
              Flyout.of(ctx).close();
              onDuplicate?.call();
            },
          ),
          MenuFlyoutItem(
            leading: Icon(
              prompt.isFavorite
                  ? FluentIcons.heart_broken
                  : FluentIcons.heart,
            ),
            text: Text(prompt.isFavorite ? '取消收藏' : '收藏'),
            onPressed: () {
              Flyout.of(ctx).close();
              onFavoriteToggle?.call();
            },
          ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: Icon(FluentIcons.delete, color: AppColors.error(FluentTheme.of(ctx).brightness)),
            text: Text('删除', style: TextStyle(color: AppColors.error(FluentTheme.of(ctx).brightness))),
            onPressed: () {
              Flyout.of(ctx).close();
              onDelete?.call();
            },
          ),
        ],
      );
    },
  );
}
