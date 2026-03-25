import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/utils/format_utils.dart';
import 'asset_context_menu.dart';
import 'asset_thumbnail.dart';
import 'asset_type_helpers.dart';

class AssetListItem extends StatefulWidget {
  const AssetListItem({
    super.key,
    required this.asset,
    this.isSelected = false,
    this.onTap,
    this.onFavoriteToggle,
    this.onDelete,
    this.onRename,
  });

  final Asset asset;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onRename;

  @override
  State<AssetListItem> createState() => _AssetListItemState();
}

class _AssetListItemState extends State<AssetListItem> {
  bool _isHovered = false;
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final createdAt = DateTime.fromMillisecondsSinceEpoch(widget.asset.createdAt);
    final dateStr = formatDateTime(createdAt);

    return GestureDetector(
      onTap: widget.onTap,
      onSecondaryTapUp: (details) => _showContextMenu(context, details),
      child: FlyoutTarget(
        controller: _flyoutController,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: _buildListItemSurface(theme, dateStr),
        ),
      ),
    );
  }

  Widget _buildListItemSurface(FluentThemeData theme, String dateStr) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(vertical: 1),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isSelected
            ? theme.accentColor.withValues(alpha: 0.1)
            : _isHovered
                ? theme.resources.subtleFillColorSecondary
                : Colors.transparent,
        borderRadius: DesignTokens.borderRadiusSM,
        border: widget.isSelected
            ? Border.all(color: theme.accentColor.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          _buildSelectionIndicator(theme),
          _buildThumbnailArea(),
          const SizedBox(width: 12),
          _buildNameCell(theme),
          const SizedBox(width: 12),
          _buildTypeCell(theme),
          const SizedBox(width: 12),
          _buildFileSizeCell(theme),
          const SizedBox(width: 12),
          _buildSourceCell(theme),
          const SizedBox(width: 12),
          _buildDateCell(theme, dateStr),
          if (widget.asset.isFavorite) _buildFavoriteIndicator(),
        ],
      ),
    );
  }

  Widget _buildSelectionIndicator(FluentThemeData theme) {
    if (widget.isSelected) {
      return Container(
        width: 20,
        height: 20,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: theme.accentColor,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          FluentIcons.check_mark,
          size: 10,
          color: AppColors.onAccent,
        ),
      );
    }
    return const SizedBox(width: 28);
  }

  Widget _buildThumbnailArea() {
    return SizedBox(
      width: 36,
      height: 36,
      child: AssetThumbnail(
        asset: widget.asset,
        showFavorite: false,
      ),
    );
  }

  Widget _buildNameCell(FluentThemeData theme) {
    return Expanded(
      flex: 3,
      child: Text(
        widget.asset.name,
        style: theme.typography.body?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildTypeCell(FluentThemeData theme) {
    return SizedBox(
      width: 60,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            assetTypeIcon(widget.asset.type),
            size: DesignTokens.iconXS,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(width: 4),
          Text(
            assetTypeLabel(widget.asset.type),
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileSizeCell(FluentThemeData theme) {
    return SizedBox(
      width: 80,
      child: Text(
        formatFileSize(widget.asset.fileSize),
        style: theme.typography.caption?.copyWith(
          color: theme.resources.textFillColorSecondary,
        ),
      ),
    );
  }

  Widget _buildSourceCell(FluentThemeData theme) {
    return SizedBox(
      width: 60,
      child: Text(
        assetSourceLabel(widget.asset.sourceType),
        style: theme.typography.caption?.copyWith(
          color: theme.resources.textFillColorSecondary,
        ),
      ),
    );
  }

  Widget _buildDateCell(FluentThemeData theme, String dateStr) {
    return SizedBox(
      width: 130,
      child: Text(
        dateStr,
        style: theme.typography.caption?.copyWith(
          color: theme.resources.textFillColorTertiary,
        ),
      ),
    );
  }

  Widget _buildFavoriteIndicator() {
    return const Padding(
      padding: EdgeInsets.only(left: 8),
      child: Icon(
        FluentIcons.heart_fill,
        size: DesignTokens.iconXS,
        color: AppColors.favorite,
      ),
    );
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) {
    showAssetContextMenu(
      context: context,
      controller: _flyoutController,
      position: details.globalPosition,
      asset: widget.asset,
      onFavoriteToggle: widget.onFavoriteToggle,
      onRename: widget.onRename,
      onDelete: widget.onDelete,
    );
  }
}
