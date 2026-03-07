import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../assets/providers/assets_provider.dart';
import '../../assets/views/asset_import_dialog.dart';
import '../../assets/widgets/asset_grid_item.dart';
import '../../assets/widgets/asset_list_item.dart';

class ProjectAssetsTab extends ConsumerStatefulWidget {
  const ProjectAssetsTab({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectAssetsTab> createState() => _ProjectAssetsTabState();
}

class _ProjectAssetsTabState extends ConsumerState<ProjectAssetsTab> {
  bool _gridMode = true;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final assetsAsync = ref.watch(assetsByProjectProvider(widget.projectId));

    return Column(
      children: [
        _buildToolbar(theme),
        const Divider(),
        Expanded(
          child: assetsAsync.when(
            loading: () => const LoadingIndicator(message: '加载资产...'),
            error: (e, _) => Center(
              child: InfoBar(
                title: const Text('加载失败'),
                content: Text('$e'),
                severity: InfoBarSeverity.error,
              ),
            ),
            data: (assets) {
              if (assets.isEmpty) {
                return EmptyState(
                  icon: FluentIcons.photo_collection,
                  title: '暂无资产',
                  description: '导入文件到此项目',
                  action: FilledButton(
                    onPressed: _showImportDialog,
                    child: const Text('导入资产'),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(16),
                child: _gridMode
                    ? _buildGridView(assets)
                    : _buildListView(assets),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          ToggleSwitch(
            checked: !_gridMode,
            onChanged: (v) => setState(() => _gridMode = !v),
            content: Text(
              _gridMode ? '网格' : '列表',
              style: theme.typography.caption,
            ),
          ),
          const Spacer(),
          HyperlinkButton(
            onPressed: () => context.go(AppRoutes.assets),
            child: const Text('查看全部'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _showImportDialog,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.add, size: 14),
                SizedBox(width: 6),
                Text('导入'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridView(List<Asset> assets) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            (constraints.maxWidth / 200).floor().clamp(2, 8);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.85,
          ),
          itemCount: assets.length,
          itemBuilder: (context, index) {
            final asset = assets[index];
            return AssetGridItem(
              asset: asset,
              onTap: () => context.go('${AppRoutes.assets}/${asset.id}'),
              onFavoriteToggle: () =>
                  ref.read(assetActionsProvider).toggleFavorite(asset.id),
              onDelete: () => _confirmDelete(asset),
            );
          },
        );
      },
    );
  }

  Widget _buildListView(List<Asset> assets) {
    return ListView.builder(
      itemCount: assets.length,
      itemBuilder: (context, index) {
        final asset = assets[index];
        return AssetListItem(
          asset: asset,
          onTap: () => context.go('${AppRoutes.assets}/${asset.id}'),
          onFavoriteToggle: () =>
              ref.read(assetActionsProvider).toggleFavorite(asset.id),
          onDelete: () => _confirmDelete(asset),
        );
      },
    );
  }

  Future<void> _showImportDialog() async {
    final count = await AssetImportDialog.show(
      context,
      initialProjectId: widget.projectId,
    );
    if (count != null && count > 0 && mounted) {
      await displayInfoBar(
        context,
        builder: (context, close) => InfoBar(
          title: Text('成功导入 $count 个文件'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(Asset asset) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除资产「${asset.name}」吗？此操作不可恢复。'),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppColors.error(FluentTheme.of(context).brightness)),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(assetActionsProvider).deleteAsset(asset.id);
    }
  }
}
