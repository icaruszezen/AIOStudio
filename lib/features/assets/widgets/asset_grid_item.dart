import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/utils/format_utils.dart';
import 'asset_context_menu.dart';
import 'asset_thumbnail.dart';

class AssetGridItem extends StatefulWidget {
  const AssetGridItem({
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
  State<AssetGridItem> createState() => _AssetGridItemState();
}

class _AssetGridItemState extends State<AssetGridItem> {
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

    return GestureDetector(
      onTap: widget.onTap,
      onSecondaryTapUp: (details) => _showContextMenu(context, details),
      child: FlyoutTarget(
        controller: _flyoutController,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? theme.accentColor.withValues(alpha: 0.08)
                  : theme.cardColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: widget.isSelected
                    ? theme.accentColor
                    : _isHovered
                        ? theme.accentColor.withValues(alpha: 0.4)
                        : theme.resources.cardStrokeColorDefault,
                width: widget.isSelected ? 2 : 1,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: theme.accentColor.withValues(alpha: 0.06),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  flex: 3,
                  child: AssetThumbnail(
                    asset: widget.asset,
                    isSelected: widget.isSelected,
                    isFavorite: widget.asset.isFavorite,
                    onFavoriteToggle: widget.onFavoriteToggle,
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.asset.name,
                          style: theme.typography.caption?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          formatFileSize(widget.asset.fileSize),
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) {
    showAssetContextMenu(
      context: context,
      controller: _flyoutController,
      position: details.localPosition,
      asset: widget.asset,
      onFavoriteToggle: widget.onFavoriteToggle,
      onRename: widget.onRename,
      onDelete: widget.onDelete,
    );
  }

}
