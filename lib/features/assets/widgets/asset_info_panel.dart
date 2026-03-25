import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart'
    show activeProjectsProvider;
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/error_utils.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../shared/utils/format_utils.dart';
import '../providers/assets_provider.dart';
import 'asset_tag_editor.dart';
import 'asset_type_helpers.dart';

class AssetInfoPanel extends ConsumerStatefulWidget {
  const AssetInfoPanel({
    super.key,
    required this.asset,
    required this.onDeleted,
  });

  final Asset asset;
  final VoidCallback onDeleted;

  @override
  ConsumerState<AssetInfoPanel> createState() => _AssetInfoPanelState();
}

class _AssetInfoPanelState extends ConsumerState<AssetInfoPanel> {
  late final TextEditingController _nameController;
  Timer? _debounce;

  Asset get _asset => widget.asset;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: _asset.name);
  }

  @override
  void didUpdateWidget(covariant AssetInfoPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != _asset.id) {
      _debounce?.cancel();
      _nameController.text = _asset.name;
    } else if (oldWidget.asset.name != _asset.name &&
        !(_debounce?.isActive ?? false)) {
      _nameController.text = _asset.name;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (value.trim().isNotEmpty && value.trim() != _asset.name) {
        ref.read(assetActionsProvider).updateAsset(
              id: _asset.id,
              name: value.trim(),
            );
      }
    });
  }

  Future<void> _onProjectChanged(String? projectId) async {
    await ref.read(assetActionsProvider).moveToProject(_asset.id, projectId);
  }

  Future<void> _toggleFavorite() async {
    await ref.read(assetActionsProvider).toggleFavorite(_asset.id);
  }

  Future<void> _openOrShare() async {
    try {
      if (PlatformUtils.isMobile) {
        await Share.shareXFiles([XFile(_asset.filePath)]);
      } else if (defaultTargetPlatform == TargetPlatform.windows) {
        await Process.run('explorer', ['/select,', _asset.filePath]);
      } else if (defaultTargetPlatform == TargetPlatform.macOS) {
        await Process.run('open', ['-R', _asset.filePath]);
      } else {
        await Process.run('xdg-open', [p.dirname(_asset.filePath)]);
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (_, close) {
          return InfoBar(
            title: Text(PlatformUtils.isMobile ? '分享失败' : '无法打开文件管理器'),
            content: Text(formatUserError(e)),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }

  Future<void> _exportFile() async {
    try {
      final result = await FilePicker.platform.saveFile(
        dialogTitle: '导出资产',
        fileName: p.basename(_asset.filePath),
      );
      if (result == null) return;
      await File(_asset.filePath).copy(result);
      if (mounted) {
        await displayInfoBar(context, builder: (_, close) {
          return InfoBar(
            title: const Text('导出成功'),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(context, builder: (_, close) {
          return InfoBar(
            title: const Text('导出失败'),
            content: Text(formatUserError(e)),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('删除资产'),
        content: Text('确定要删除 "${_asset.name}" 吗？此操作不可恢复。'),
        actions: [
          Button(
            child: const Text('取消'),
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(AppColors.error(FluentTheme.of(context).brightness)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(assetActionsProvider).deleteAsset(_asset.id);
      widget.onDeleted();
    }
  }

  Future<void> _openOriginalUrl() async {
    final url = _asset.originalUrl;
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri != null) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final projectsAsync = ref.watch(activeProjectsProvider);
    final projects = projectsAsync.value ?? <Project>[];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Name
        TextBox(
          controller: _nameController,
          placeholder: '资产名称',
          onChanged: _onNameChanged,
          style: theme.typography.bodyStrong,
        ),
        const SizedBox(height: 16),

        // Project
        Text('所属项目', style: theme.typography.caption),
        const SizedBox(height: 4),
        ComboBox<String?>(
          value: _asset.projectId,
          placeholder: const Text('无项目'),
          isExpanded: true,
          items: [
            const ComboBoxItem<String?>(
              value: null,
              child: Text('无项目'),
            ),
            ...projects.map(
              (proj) => ComboBoxItem<String?>(
                value: proj.id,
                child: Text(proj.name),
              ),
            ),
          ],
          onChanged: _onProjectChanged,
        ),
        const SizedBox(height: 16),

        // Type
        Row(
          children: [
            Icon(assetTypeIcon(_asset.type), size: 16),
            const SizedBox(width: 8),
            Text(
              assetTypeLabel(_asset.type),
              style: theme.typography.body,
            ),
            const Spacer(),
            Tooltip(
              message: _asset.isFavorite ? '取消收藏' : '收藏',
              child: ToggleButton(
                checked: _asset.isFavorite,
                onChanged: (_) => _toggleFavorite(),
                child: Icon(
                  _asset.isFavorite
                      ? FluentIcons.favorite_star_fill
                      : FluentIcons.favorite_star,
                  size: 16,
                  color: _asset.isFavorite ? AppColors.warning(theme.brightness) : null,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Tags
        Text('标签', style: theme.typography.caption),
        const SizedBox(height: 4),
        AssetTagEditor(assetId: _asset.id),
        const SizedBox(height: 20),

        // File info
        Expander(
          header: const Text('文件信息'),
          initiallyExpanded: true,
          content: Column(
            children: [
              _infoRow(theme, '路径', _asset.filePath),
              _infoRow(theme, '大小', formatFileSize(_asset.fileSize)),
              if (_asset.width != null && _asset.height != null)
                _infoRow(
                    theme, '尺寸', '${_asset.width} × ${_asset.height}'),
              if (_asset.duration != null)
                _infoRow(theme, '时长',
                    formatDurationFromSeconds(_asset.duration!)),
              _infoRow(
                  theme, '格式', p.extension(_asset.filePath).toUpperCase()),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Source info
        Expander(
          header: const Text('来源信息'),
          content: Column(
            children: [
              _infoRow(
                  theme, '来源', assetSourceLabel(_asset.sourceType)),
              if (_asset.originalUrl != null &&
                  _asset.originalUrl!.isNotEmpty)
                _infoRowWithAction(
                  theme,
                  '原始 URL',
                  _asset.originalUrl!,
                  '打开',
                  _openOriginalUrl,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Time info
        Expander(
          header: const Text('时间信息'),
          content: Column(
            children: [
              _infoRow(
                theme,
                '创建时间',
                formatDateTime(
                  DateTime.fromMillisecondsSinceEpoch(_asset.createdAt),
                ),
              ),
              _infoRow(
                theme,
                '修改时间',
                formatDateTime(
                  DateTime.fromMillisecondsSinceEpoch(_asset.updatedAt),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Action buttons
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Button(
              onPressed: _openOrShare,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PlatformUtils.isMobile
                        ? FluentIcons.share
                        : FluentIcons.open_folder_horizontal,
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(PlatformUtils.isMobile ? '分享' : '在文件管理器中打开'),
                ],
              ),
            ),
            Button(
              onPressed: _exportFile,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.download, size: 14),
                  SizedBox(width: 6),
                  Text('导出'),
                ],
              ),
            ),
            Button(
              onPressed: _confirmDelete,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.delete, size: 14, color: AppColors.error(theme.brightness)),
                  const SizedBox(width: 6),
                  Text('删除', style: TextStyle(color: AppColors.error(theme.brightness))),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _infoRow(FluentThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.typography.caption,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoRowWithAction(
    FluentThemeData theme,
    String label,
    String value,
    String actionLabel,
    VoidCallback onAction,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.typography.caption,
              maxLines: 2,
            ),
          ),
          const SizedBox(width: 4),
          HyperlinkButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

}
