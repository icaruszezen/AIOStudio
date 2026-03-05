import 'dart:math' as math;

import 'package:desktop_drop/desktop_drop.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../projects/providers/projects_provider.dart';
import '../providers/asset_filter_provider.dart';
import '../providers/assets_provider.dart';
import '../providers/tags_provider.dart';
import '../widgets/asset_filter_bar.dart';
import '../widgets/asset_grid_item.dart';
import '../widgets/asset_list_item.dart';
import '../widgets/asset_tag_editor.dart';
import 'asset_import_dialog.dart';

class AssetsPage extends ConsumerStatefulWidget {
  const AssetsPage({super.key});

  @override
  ConsumerState<AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends ConsumerState<AssetsPage> {
  final Set<String> _selectedIds = {};
  bool _isDragging = false;
  int? _lastSelectedIndex;

  bool get _hasSelection => _selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    ref.listen(assetFilterProvider, (prev, next) {
      if (prev != next) {
        setState(() {
          _selectedIds.clear();
          _lastSelectedIndex = null;
        });
      }
    });

    final theme = FluentTheme.of(context);
    final filter = ref.watch(assetFilterProvider);
    final filteredAsync = ref.watch(filteredAssetsProvider);
    final projectsAsync = ref.watch(activeProjectsProvider);
    final projects = projectsAsync.value ?? <Project>[];

    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        final paths = details.files.map((f) => f.path).toList();
        if (paths.isNotEmpty) {
          _showImportDialog(initialFiles: paths);
        }
      },
      child: Stack(
        children: [
          ScaffoldPage(
            padding: EdgeInsets.zero,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_hasSelection)
                  _buildMultiSelectBar(theme)
                else
                  _buildToolbar(theme, filter, projects),
                AssetFilterBar(projects: projects),
                const Divider(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: filteredAsync.when(
                      loading: () =>
                          const LoadingIndicator(message: '加载资产中...'),
                      error: (e, _) => Center(
                        child: InfoBar(
                          title: const Text('加载失败'),
                          content: Text('$e'),
                          severity: InfoBarSeverity.error,
                        ),
                      ),
                      data: (assets) {
                        if (assets.isEmpty) {
                          return _buildEmptyState(filter);
                        }
                        return filter.viewMode == AssetViewMode.grid
                            ? _buildGridView(assets)
                            : _buildListView(assets);
                      },
                    ),
                  ),
                ),
                _buildStatusBar(theme, filteredAsync),
              ],
            ),
          ),
          if (_isDragging) _buildDragOverlay(theme),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toolbar
  // ---------------------------------------------------------------------------

  Widget _buildToolbar(
    FluentThemeData theme,
    AssetFilterState filter,
    List<Project> projects,
  ) {
    final notifier = ref.read(assetFilterProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('资产库', style: theme.typography.title),
              const Spacer(),
              FilledButton(
                onPressed: () => _showImportDialog(),
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
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 220,
                child: AutoSuggestBox<String>(
                  placeholder: '搜索资产...',
                  items: const [],
                  onChanged: (text, _) => notifier.setSearchQuery(text),
                  leadingIcon: const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(FluentIcons.search, size: 14),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('类型:', style: theme.typography.caption),
              const SizedBox(width: 6),
              ComboBox<String?>(
                value: filter.typeFilter,
                items: const [
                  ComboBoxItem(value: null, child: Text('全部')),
                  ComboBoxItem(value: 'image', child: Text('图片')),
                  ComboBoxItem(value: 'video', child: Text('视频')),
                  ComboBoxItem(value: 'audio', child: Text('音频')),
                  ComboBoxItem(value: 'text', child: Text('文本')),
                ],
                onChanged: (v) => notifier.setTypeFilter(v),
              ),
              const SizedBox(width: 12),
              Text('项目:', style: theme.typography.caption),
              const SizedBox(width: 6),
              ComboBox<String?>(
                value: filter.projectFilter,
                items: [
                  const ComboBoxItem(value: null, child: Text('全部')),
                  ...projects.map(
                    (p) => ComboBoxItem(value: p.id, child: Text(p.name)),
                  ),
                ],
                onChanged: (v) => notifier.setProjectFilter(v),
              ),
              const SizedBox(width: 12),
              _TagFilterButton(
                selectedTagIds: filter.tagFilters,
                onToggle: notifier.toggleTagFilter,
              ),
              const SizedBox(width: 12),
              Text('排序:', style: theme.typography.caption),
              const SizedBox(width: 6),
              ComboBox<AssetSortField>(
                value: filter.sortField,
                items: const [
                  ComboBoxItem(
                    value: AssetSortField.createdAt,
                    child: Text('创建时间'),
                  ),
                  ComboBoxItem(
                    value: AssetSortField.name,
                    child: Text('名称'),
                  ),
                  ComboBoxItem(
                    value: AssetSortField.fileSize,
                    child: Text('文件大小'),
                  ),
                  ComboBoxItem(
                    value: AssetSortField.type,
                    child: Text('类型'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) notifier.setSortField(v);
                },
              ),
              const Spacer(),
              ToggleSwitch(
                checked: filter.viewMode == AssetViewMode.list,
                onChanged: (v) => notifier.setViewMode(
                  v ? AssetViewMode.list : AssetViewMode.grid,
                ),
                content: Text(
                  filter.viewMode == AssetViewMode.grid ? '网格' : '列表',
                  style: theme.typography.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Multi-select bar
  // ---------------------------------------------------------------------------

  Widget _buildMultiSelectBar(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
      color: theme.accentColor.withValues(alpha: 0.06),
      child: Row(
        children: [
          Text(
            '已选择 ${_selectedIds.length} 个资产',
            style: theme.typography.bodyStrong,
          ),
          const SizedBox(width: 16),
          Button(
            onPressed: _selectAll,
            child: const Text('全选'),
          ),
          const SizedBox(width: 8),
          Button(
            onPressed: () => setState(() {
              _selectedIds.clear();
              _lastSelectedIndex = null;
            }),
            child: const Text('取消选择'),
          ),
          const Spacer(),
          Button(
            onPressed: _batchFavorite,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.heart, size: 14),
                SizedBox(width: 6),
                Text('收藏'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Button(
            onPressed: _batchMoveToProject,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.move_to_folder, size: 14),
                SizedBox(width: 6),
                Text('移动'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Button(
            onPressed: _batchAddTag,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.tag, size: 14),
                SizedBox(width: 6),
                Text('标签'),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _batchDelete,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.delete, size: 14),
                SizedBox(width: 6),
                Text('删除'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Grid & List views
  // ---------------------------------------------------------------------------

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
              isSelected: _selectedIds.contains(asset.id),
              onTap: () => _handleItemTap(asset, index, assets),
              onDoubleTap: () => context.go('${AppRoutes.assets}/${asset.id}'),
              onFavoriteToggle: () =>
                  ref.read(assetActionsProvider).toggleFavorite(asset.id),
              onDelete: () => _confirmDeleteSingle(asset),
              onRename: () => _showRenameDialog(asset),
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
          isSelected: _selectedIds.contains(asset.id),
          onTap: () => _handleItemTap(asset, index, assets),
          onDoubleTap: () => context.go('${AppRoutes.assets}/${asset.id}'),
          onFavoriteToggle: () =>
              ref.read(assetActionsProvider).toggleFavorite(asset.id),
          onDelete: () => _confirmDeleteSingle(asset),
          onRename: () => _showRenameDialog(asset),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Status bar
  // ---------------------------------------------------------------------------

  Widget _buildStatusBar(FluentThemeData theme, AsyncValue<List<Asset>> data) {
    final total = data.value?.length ?? 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.resources.cardStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          Text(
            '共 $total 个资产',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
          if (_hasSelection) ...[
            Text(
              ' · 已选择 ${_selectedIds.length} 个',
              style: theme.typography.caption?.copyWith(
                color: theme.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty & drag overlay
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(AssetFilterState filter) {
    if (filter.hasActiveFilters) {
      return EmptyState(
        icon: FluentIcons.filter,
        title: '没有匹配的资产',
        description: '尝试调整筛选条件',
        action: Button(
          onPressed: () => ref.read(assetFilterProvider.notifier).clearAll(),
          child: const Text('清除筛选'),
        ),
      );
    }
    return EmptyState(
      icon: FluentIcons.photo_collection,
      title: '还没有资产',
      description: '导入本地文件或从浏览器扩展抓取资源',
      action: FilledButton(
        onPressed: () => _showImportDialog(),
        child: const Text('导入资产'),
      ),
    );
  }

  Widget _buildDragOverlay(FluentThemeData theme) {
    return Positioned.fill(
      child: Container(
        color: theme.accentColor.withValues(alpha: 0.1),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.accentColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.cloud_upload,
                  size: 48,
                  color: theme.accentColor,
                ),
                const SizedBox(height: 12),
                Text(
                  '释放以导入资产',
                  style: theme.typography.subtitle?.copyWith(
                    color: theme.accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Selection logic
  // ---------------------------------------------------------------------------

  void _handleItemTap(Asset asset, int index, List<Asset> assets) {
    final isCtrlPressed =
        HardwareKeyboard.instance.logicalKeysPressed
            .any((k) => k == LogicalKeyboardKey.controlLeft ||
                k == LogicalKeyboardKey.controlRight);
    final isShiftPressed =
        HardwareKeyboard.instance.logicalKeysPressed
            .any((k) => k == LogicalKeyboardKey.shiftLeft ||
                k == LogicalKeyboardKey.shiftRight);

    setState(() {
      if (isCtrlPressed) {
        if (_selectedIds.contains(asset.id)) {
          _selectedIds.remove(asset.id);
        } else {
          _selectedIds.add(asset.id);
        }
        _lastSelectedIndex = index;
      } else if (isShiftPressed && _lastSelectedIndex != null) {
        final start = math.min(_lastSelectedIndex!, index);
        final end = math.max(_lastSelectedIndex!, index);
        for (var i = start; i <= end; i++) {
          _selectedIds.add(assets[i].id);
        }
      } else {
        if (_selectedIds.length == 1 && _selectedIds.contains(asset.id)) {
          _selectedIds.clear();
          _lastSelectedIndex = null;
        } else {
          _selectedIds
            ..clear()
            ..add(asset.id);
          _lastSelectedIndex = index;
        }
      }
    });
  }

  void _selectAll() {
    final assets = ref.read(filteredAssetsProvider).value ?? <Asset>[];
    setState(() {
      _selectedIds.addAll(assets.map((a) => a.id));
    });
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _showImportDialog({List<String>? initialFiles}) async {
    final count = await AssetImportDialog.show(
      context,
      initialFiles: initialFiles,
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

  Future<void> _confirmDeleteSingle(Asset asset) async {
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
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(assetActionsProvider).deleteAsset(asset.id);
      if (!mounted) return;
      setState(() => _selectedIds.remove(asset.id));
    }
  }

  Future<void> _batchDelete() async {
    final count = _selectedIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('确认批量删除'),
        content: Text('确定要删除选中的 $count 个资产吗？此操作不可恢复。'),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(assetActionsProvider).deleteAssets(_selectedIds.toList());
      if (!mounted) return;
      setState(() {
        _selectedIds.clear();
        _lastSelectedIndex = null;
      });
    }
  }

  Future<void> _batchFavorite() async {
    await ref
        .read(assetActionsProvider)
        .batchToggleFavorite(_selectedIds.toList(), favorite: true);
  }

  Future<void> _batchMoveToProject() async {
    final projects = ref.read(activeProjectsProvider).value ?? <Project>[];
    String? selectedProject;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => ContentDialog(
          title: const Text('移动到项目'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('将 ${_selectedIds.length} 个资产移动到:'),
              const SizedBox(height: 12),
              ComboBox<String?>(
                value: selectedProject,
                placeholder: const Text('选择目标项目'),
                items: [
                  const ComboBoxItem(value: null, child: Text('不关联项目')),
                  ...projects.map(
                    (p) => ComboBoxItem(value: p.id, child: Text(p.name)),
                  ),
                ],
                onChanged: (v) => setDialogState(() => selectedProject = v),
                isExpanded: true,
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('移动'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await ref
          .read(assetActionsProvider)
          .batchMoveToProject(_selectedIds.toList(), selectedProject);
    }
  }

  Future<void> _batchAddTag() async {
    await showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('批量添加标签'),
        content: SizedBox(
          width: 360,
          child: _BatchTagSelector(assetIds: _selectedIds.toList()),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('完成'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRenameDialog(Asset asset) async {
    final controller = TextEditingController(text: asset.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('重命名'),
        content: TextBox(
          controller: controller,
          placeholder: '输入新名称',
          autofocus: true,
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final newName = controller.text.trim();
      if (newName.isNotEmpty && newName != asset.name) {
        await ref.read(assetActionsProvider).updateAsset(
              id: asset.id,
              name: newName,
            );
      }
    }
    controller.dispose();
  }
}

// ---------------------------------------------------------------------------
// Tag filter flyout button
// ---------------------------------------------------------------------------

class _TagFilterButton extends StatefulWidget {
  const _TagFilterButton({
    required this.selectedTagIds,
    required this.onToggle,
  });

  final Set<String> selectedTagIds;
  final void Function(String tagId) onToggle;

  @override
  State<_TagFilterButton> createState() => _TagFilterButtonState();
}

class _TagFilterButtonState extends State<_TagFilterButton> {
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return FlyoutTarget(
      controller: _flyoutController,
      child: Button(
        onPressed: () {
          _flyoutController.showFlyout(
            navigatorKey: Navigator.of(context, rootNavigator: true),
            barrierDismissible: true,
            placementMode: FlyoutPlacementMode.bottomCenter,
            builder: (ctx) => FlyoutContent(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('选择标签', style: theme.typography.bodyStrong),
                    const SizedBox(height: 8),
                    TagSelectorPanel(
                      selectedTagIds: widget.selectedTagIds,
                      onToggle: widget.onToggle,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(FluentIcons.tag, size: 14),
            const SizedBox(width: 6),
            Text('标签${widget.selectedTagIds.isNotEmpty ? ' (${widget.selectedTagIds.length})' : ''}'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Batch tag selector (used in dialog)
// ---------------------------------------------------------------------------

class _BatchTagSelector extends ConsumerWidget {
  const _BatchTagSelector({required this.assetIds});

  final List<String> assetIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final tagsAsync = ref.watch(allTagsProvider);

    return tagsAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Text('$e'),
      data: (tags) {
        if (tags.isEmpty) {
          return Text(
            '暂无标签，请先创建标签',
            style: theme.typography.body,
          );
        }
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tags.map((tag) {
            final chipColor = tag.color != null
                ? Color(tag.color!)
                : theme.accentColor;
            return Button(
              onPressed: () async {
                await ref
                    .read(tagActionsProvider)
                    .batchAddToAssets(assetIds, tag.id);
                if (context.mounted) {
                  await displayInfoBar(
                    context,
                    builder: (context, close) => InfoBar(
                      title: Text('已为 ${assetIds.length} 个资产添加标签 "${tag.name}"'),
                      severity: InfoBarSeverity.success,
                      action: IconButton(
                        icon: const Icon(FluentIcons.clear),
                        onPressed: close,
                      ),
                    ),
                  );
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: chipColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(tag.name),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
