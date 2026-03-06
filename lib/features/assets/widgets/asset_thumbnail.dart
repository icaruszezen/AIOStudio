import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/database/app_database.dart';
import 'asset_type_helpers.dart';

class AssetThumbnail extends StatelessWidget {
  const AssetThumbnail({
    super.key,
    required this.asset,
    this.isSelected = false,
    this.isFavorite = false,
    this.showFavorite = true,
    this.onFavoriteToggle,
    this.size,
  });

  final Asset asset;
  final bool isSelected;
  final bool isFavorite;
  final bool showFavorite;
  final VoidCallback? onFavoriteToggle;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          child: _buildContent(theme),
        ),
        _buildTypeIndicator(theme),
        if (showFavorite && isFavorite) _buildFavoriteIndicator(theme),
        if (isSelected) _buildSelectionOverlay(theme),
      ],
    );
  }

  Widget _buildContent(FluentThemeData theme) {
    return switch (asset.type) {
      'image' => _buildImageThumbnail(theme),
      'video' => _buildVideoThumbnail(theme),
      'audio' => _buildAudioThumbnail(theme),
      'text' => _buildTextThumbnail(theme),
      _ => _buildGenericThumbnail(theme),
    };
  }

  Widget _buildImageThumbnail(FluentThemeData theme) {
    final path = asset.thumbnailPath ?? asset.filePath;
    final file = File(path);
    return Image.file(
      file,
      fit: BoxFit.cover,
      cacheWidth: 300,
      cacheHeight: 300,
      errorBuilder: (_, __, ___) => _buildPlaceholder(
        theme,
        FluentIcons.photo2,
        theme.accentColor,
      ),
    );
  }

  Widget _buildVideoThumbnail(FluentThemeData theme) {
    Widget content;
    if (asset.thumbnailPath != null) {
      content = Image.file(
        File(asset.thumbnailPath!),
        fit: BoxFit.cover,
        cacheWidth: 300,
        cacheHeight: 300,
        errorBuilder: (_, __, ___) => _buildPlaceholder(
          theme,
          FluentIcons.video,
          const Color(0xFF8B5CF6),
        ),
      );
    } else {
      content = _buildPlaceholder(
        theme,
        FluentIcons.video,
        const Color(0xFF8B5CF6),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              FluentIcons.play,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        if (asset.duration != null)
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _formatDuration(asset.duration!),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAudioThumbnail(FluentThemeData theme) {
    return _buildPlaceholder(
      theme,
      FluentIcons.music_in_collection,
      const Color(0xFF10B981),
    );
  }

  Widget _buildTextThumbnail(FluentThemeData theme) {
    return _buildPlaceholder(
      theme,
      FluentIcons.text_document,
      const Color(0xFF3B82F6),
    );
  }

  Widget _buildGenericThumbnail(FluentThemeData theme) {
    return _buildPlaceholder(
      theme,
      FluentIcons.document,
      theme.resources.textFillColorSecondary,
    );
  }

  Widget _buildPlaceholder(FluentThemeData theme, IconData icon, Color color) {
    return Container(
      color: theme.resources.subtleFillColorSecondary,
      child: Center(
        child: Icon(icon, size: 32, color: color),
      ),
    );
  }

  Widget _buildTypeIndicator(FluentThemeData theme) {
    final icon = assetTypeIcon(asset.type);
    final label = assetTypeLabel(asset.type);

    return Positioned(
      left: 6,
      top: 6,
      child: Tooltip(
        message: label,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildFavoriteIndicator(FluentThemeData theme) {
    return Positioned(
      right: 6,
      top: 6,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          FluentIcons.heart_fill,
          size: 12,
          color: Color(0xFFEF4444),
        ),
      ),
    );
  }

  Widget _buildSelectionOverlay(FluentThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.2),
        border: Border.all(color: theme.accentColor, width: 2),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
      ),
      child: Align(
        alignment: Alignment.topRight,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: theme.accentColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              FluentIcons.check_mark,
              size: 12,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  static String _formatDuration(double seconds) {
    final mins = seconds ~/ 60;
    final secs = (seconds % 60).round();
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
