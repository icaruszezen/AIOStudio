import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/breadcrumb_navigation.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/asset_navigation_provider.dart';
import '../providers/assets_provider.dart';
import '../widgets/asset_info_panel.dart';
import '../widgets/audio_player_widget.dart';
import '../widgets/image_viewer.dart';
import '../widgets/text_preview_widget.dart';
import '../widgets/video_player_widget.dart';

class AssetDetailPage extends ConsumerStatefulWidget {
  const AssetDetailPage({super.key, required this.assetId});

  final String assetId;

  @override
  ConsumerState<AssetDetailPage> createState() => _AssetDetailPageState();
}

class _AssetDetailPageState extends ConsumerState<AssetDetailPage> {
  static const _narrowBreakpoint = 800.0;
  static const _minPanelWidth = 240.0;
  static const _maxPanelFraction = 0.5;

  bool _showInfoPanel = true;
  double _infoPanelWidth = 320.0;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(currentAssetIdProvider.notifier).set(widget.assetId);
      }
    });
  }

  @override
  void didUpdateWidget(covariant AssetDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ref.read(currentAssetIdProvider.notifier).set(widget.assetId);
        }
      });
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _navigateTo(String? assetId) {
    if (assetId == null) return;
    context.go('${AppRoutes.assets}/$assetId');
  }

  void _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final prevId = ref.read(previousAssetIdProvider);
    final nextId = ref.read(nextAssetIdProvider);

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      context.go(AppRoutes.assets);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _navigateTo(prevId);
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _navigateTo(nextId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final assetAsync = ref.watch(assetDetailProvider(widget.assetId));
    final theme = FluentTheme.of(context);

    return KeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _onKeyEvent,
      child: assetAsync.when(
        loading: () => const LoadingIndicator(),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (asset) {
          if (asset == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.unknown,
                      size: 48,
                      color: theme.resources.textFillColorSecondary),
                  const SizedBox(height: 8),
                  Text('资产不存在', style: theme.typography.subtitle),
                  const SizedBox(height: 16),
                  Button(
                    onPressed: () => context.go(AppRoutes.assets),
                    child: const Text('返回资产库'),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(theme, asset),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < _narrowBreakpoint;
                    return isNarrow
                        ? _buildVerticalLayout(theme, asset)
                        : _buildHorizontalLayout(
                            theme, asset, constraints.maxWidth);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme, Asset asset) {
    final prevId = ref.watch(previousAssetIdProvider);
    final nextId = ref.watch(nextAssetIdProvider);
    final navInfo = ref.watch(assetNavigationInfoProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.resources.cardStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          Tooltip(
            message: '返回资产库',
            child: IconButton(
              icon: const Icon(FluentIcons.back, size: 14),
              onPressed: () => context.go(AppRoutes.assets),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: BreadcrumbNavigation(
              items: [
                BreadcrumbEntry(
                  label: '资产库',
                  onTap: () => context.go(AppRoutes.assets),
                ),
                BreadcrumbEntry(label: asset.name),
              ],
            ),
          ),
          if (navInfo.isNotEmpty)
            Text(
              navInfo,
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(FluentIcons.chevron_left, size: 12,
                color: prevId == null
                    ? theme.resources.textFillColorDisabled
                    : null),
            onPressed: prevId != null ? () => _navigateTo(prevId) : null,
          ),
          IconButton(
            icon: Icon(FluentIcons.chevron_right, size: 12,
                color: nextId == null
                    ? theme.resources.textFillColorDisabled
                    : null),
            onPressed: nextId != null ? () => _navigateTo(nextId) : null,
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: _showInfoPanel ? '隐藏信息面板' : '显示信息面板',
            child: IconButton(
              icon: Icon(
                _showInfoPanel ? FluentIcons.side_panel : FluentIcons.open_pane,
                size: 14,
              ),
              onPressed: () =>
                  setState(() => _showInfoPanel = !_showInfoPanel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalLayout(
      FluentThemeData theme, Asset asset, double totalWidth) {
    final maxInfoWidth = totalWidth * _maxPanelFraction;
    final clampedInfoWidth =
        _infoPanelWidth.clamp(_minPanelWidth, maxInfoWidth);

    return Row(
      children: [
        Expanded(child: _buildPreviewArea(asset)),
        if (_showInfoPanel) ...[
          _buildDragHandle(theme, totalWidth),
          SizedBox(
            width: clampedInfoWidth,
            child: AssetInfoPanel(
              asset: asset,
              onDeleted: () => context.go(AppRoutes.assets),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVerticalLayout(FluentThemeData theme, Asset asset) {
    return Column(
      children: [
        Expanded(
          flex: _showInfoPanel ? 6 : 10,
          child: _buildPreviewArea(asset),
        ),
        if (_showInfoPanel) ...[
          Container(
            height: 1,
            color: theme.resources.cardStrokeColorDefault,
          ),
          Expanded(
            flex: 4,
            child: AssetInfoPanel(
              asset: asset,
              onDeleted: () => context.go(AppRoutes.assets),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDragHandle(FluentThemeData theme, double totalWidth) {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _infoPanelWidth -= details.delta.dx;
          final maxW = totalWidth * _maxPanelFraction;
          _infoPanelWidth = _infoPanelWidth.clamp(_minPanelWidth, maxW);
        });
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 4,
          color: theme.resources.cardStrokeColorDefault,
        ),
      ),
    );
  }

  Widget _buildPreviewArea(Asset asset) {
    return switch (asset.type) {
      'image' => ImageViewer(filePath: asset.filePath),
      'video' => VideoPlayerWidget(filePath: asset.filePath),
      'audio' => AudioPlayerWidget(
          filePath: asset.filePath,
          fileName: asset.name,
        ),
      'text' => TextPreviewWidget(filePath: asset.filePath),
      _ => _buildUnsupportedPreview(asset),
    };
  }

  Widget _buildUnsupportedPreview(Asset asset) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.document,
              size: 64, color: theme.resources.textFillColorSecondary),
          const SizedBox(height: 12),
          Text(asset.name, style: theme.typography.subtitle),
          const SizedBox(height: 4),
          Text(
            '不支持预览此类型的文件',
            style: theme.typography.body?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
