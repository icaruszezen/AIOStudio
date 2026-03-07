import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';

void showAssetContextMenu({
  required BuildContext context,
  required FlyoutController controller,
  required Offset position,
  required Asset asset,
  VoidCallback? onFavoriteToggle,
  VoidCallback? onRename,
  VoidCallback? onDelete,
}) {
  controller.showFlyout(
    navigatorKey: Navigator.of(context, rootNavigator: true),
    position: position,
    barrierDismissible: true,
    builder: (ctx) {
      return MenuFlyout(
        items: [
          MenuFlyoutItem(
            leading: Icon(
              asset.isFavorite ? FluentIcons.heart_broken : FluentIcons.heart,
            ),
            text: Text(asset.isFavorite ? '取消收藏' : '收藏'),
            onPressed: () {
              Flyout.of(ctx).close();
              onFavoriteToggle?.call();
            },
          ),
          MenuFlyoutItem(
            leading: const Icon(FluentIcons.rename),
            text: const Text('重命名'),
            onPressed: () {
              Flyout.of(ctx).close();
              onRename?.call();
            },
          ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: Icon(FluentIcons.delete, color: AppColors.error(FluentTheme.of(context).brightness)),
            text: Text('删除', style: TextStyle(color: AppColors.error(FluentTheme.of(context).brightness))),
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
