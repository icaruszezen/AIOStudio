import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../shared/utils/error_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/projects_provider.dart';
import '../widgets/project_card.dart';
import '../widgets/project_list_tile.dart';
import 'project_create_dialog.dart';

enum _ViewMode { grid, list }

enum _SortField { name, createdAt, updatedAt }

class ProjectsPage extends ConsumerStatefulWidget {
  const ProjectsPage({super.key});

  @override
  ConsumerState<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends ConsumerState<ProjectsPage> {
  _ViewMode _viewMode = _ViewMode.grid;
  _SortField _sortField = _SortField.updatedAt;
  String _searchQuery = '';
  String _debouncedSearchQuery = '';
  bool _showArchived = false;
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String text) {
    setState(() => _searchQuery = text);
    _searchDebounce?.cancel();
    if (text.isEmpty) {
      setState(() => _debouncedSearchQuery = '');
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _debouncedSearchQuery = text);
    });
  }

  List<Project> _sortProjects(List<Project> projects) {
    final sorted = List<Project>.from(projects)
      ..sort((a, b) {
        return switch (_sortField) {
          _SortField.name => a.name.compareTo(b.name),
          _SortField.createdAt => b.createdAt.compareTo(a.createdAt),
          _SortField.updatedAt => b.updatedAt.compareTo(a.updatedAt),
        };
      });
    return sorted;
  }

  Future<void> _confirmDelete(Project project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除项目「${project.name}」吗？\n此操作将同时删除该项目下所有关联的资产、提示词和 AI 任务，且不可恢复。'),
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
      try {
        await ref.read(projectActionsProvider).delete(project.id);
      } catch (e) {
        if (mounted) {
          await displayInfoBar(
            context,
            builder: (context, close) => InfoBar(
              title: const Text('删除失败'),
              content: Text(formatUserError(e)),
              severity: InfoBarSeverity.error,
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
            ),
          );
        }
      }
    }
  }

  void _onProjectTap(Project project) {
    context.push('${AppRoutes.projects}/${project.id}');
  }

  void _onEdit(Project project) {
    ProjectCreateDialog.show(context, existing: project);
  }

  Future<void> _createProject() async {
    final newId = await ProjectCreateDialog.show(context);
    if (newId != null && mounted) {
      context.push('${AppRoutes.projects}/$newId');
    }
  }

  Future<void> _onArchive(Project project) async {
    try {
      await ref.read(projectActionsProvider).archive(project.id);
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('归档失败'),
            content: Text(formatUserError(e)),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    }
  }

  Future<void> _onUnarchive(Project project) async {
    try {
      await ref.read(projectActionsProvider).unarchive(project.id);
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('取消归档失败'),
            content: Text(formatUserError(e)),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobileLayout = constraints.maxWidth <= Breakpoints.tablet;

        return ScaffoldPage(
          padding: EdgeInsets.zero,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isMobileLayout
                  ? _buildMobileToolbar(theme)
                  : _buildToolbar(theme),
              const Divider(),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(isMobileLayout ? 12 : 20),
                  child: _searchQuery.isNotEmpty
                      ? _buildSearchResults()
                      : (_showArchived
                          ? _buildArchivedList()
                          : _buildActiveList()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  _ViewMode get _effectiveViewMode {
    if (PlatformUtils.isMobile) return _ViewMode.list;
    return _viewMode;
  }

  Widget _buildMobileToolbar(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _showArchived ? '已归档项目' : '项目',
                style: theme.typography.subtitle,
              ),
              const Spacer(),
              if (_showArchived)
                IconButton(
                  icon: const Icon(FluentIcons.back, size: 16),
                  onPressed: () => setState(() => _showArchived = false),
                )
              else ...[
                IconButton(
                  icon: const Icon(FluentIcons.archive, size: 16),
                  onPressed: () => setState(() => _showArchived = true),
                ),
                const SizedBox(width: 4),
                FilledButton(
                  onPressed: () => _createProject(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.add, size: 14),
                      SizedBox(width: 4),
                      Text('新建'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: AutoSuggestBox<String>(
              placeholder: '搜索项目...',
              items: const [],
              onChanged: (text, reason) => _onSearchChanged(text),
              leadingIcon: const Padding(
                padding: EdgeInsets.only(left: 10),
                child: Icon(FluentIcons.search, size: 14),
              ),
            ),
          ),
          if (!_showArchived) ...[
            const SizedBox(height: 8),
            ComboBox<_SortField>(
              value: _sortField,
              items: const [
                ComboBoxItem(
                    value: _SortField.updatedAt, child: Text('更新时间')),
                ComboBoxItem(
                    value: _SortField.createdAt, child: Text('创建时间')),
                ComboBoxItem(value: _SortField.name, child: Text('名称')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _sortField = v);
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _showArchived ? '已归档项目' : '项目',
                style: theme.typography.title,
              ),
              const Spacer(),
              if (_showArchived)
                Button(
                  onPressed: () => setState(() => _showArchived = false),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.back, size: 14),
                      SizedBox(width: 6),
                      Text('返回'),
                    ],
                  ),
                )
              else ...[
                Button(
                  onPressed: () => setState(() => _showArchived = true),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.archive, size: 14),
                      SizedBox(width: 6),
                      Text('已归档'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () => _createProject(),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.add, size: 14),
                      SizedBox(width: 6),
                      Text('新建项目'),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SizedBox(
                width: 260,
                child: AutoSuggestBox<String>(
                  placeholder: '搜索项目...',
                  items: const [],
                  onChanged: (text, reason) => _onSearchChanged(text),
                  leadingIcon: const Padding(
                    padding: EdgeInsets.only(left: 10),
                    child: Icon(FluentIcons.search, size: 14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              if (!_showArchived) ...[
                Text('排序:', style: theme.typography.caption),
                const SizedBox(width: 6),
                ComboBox<_SortField>(
                  value: _sortField,
                  items: const [
                    ComboBoxItem(value: _SortField.updatedAt, child: Text('更新时间')),
                    ComboBoxItem(value: _SortField.createdAt, child: Text('创建时间')),
                    ComboBoxItem(value: _SortField.name, child: Text('名称')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _sortField = v);
                  },
                ),
                const Spacer(),
                ToggleSwitch(
                  checked: _viewMode == _ViewMode.list,
                  onChanged: (v) {
                    setState(() =>
                        _viewMode = v ? _ViewMode.list : _ViewMode.grid);
                  },
                  content: Text(
                    _viewMode == _ViewMode.grid ? '网格' : '列表',
                    style: theme.typography.caption,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveList() {
    final asyncProjects = ref.watch(activeProjectsProvider);

    return asyncProjects.when(
      loading: () => const LoadingIndicator(message: '加载项目中...'),
      error: (e, _) => Center(
        child: InfoBar(
          title: const Text('加载失败'),
          content: Text(formatUserError(e)),
          severity: InfoBarSeverity.error,
        ),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return EmptyState(
            icon: FluentIcons.project_management,
            title: '还没有项目',
            description: '创建你的第一个 AGI 项目来开始工作吧',
            action: FilledButton(
              onPressed: () => _createProject(),
              child: const Text('新建项目'),
            ),
          );
        }
        final sorted = _sortProjects(projects);
        return _effectiveViewMode == _ViewMode.grid
            ? _buildGridView(sorted, archived: false)
            : _buildListView(sorted, archived: false);
      },
    );
  }

  Widget _buildArchivedList() {
    final asyncProjects = ref.watch(archivedProjectsProvider);

    return asyncProjects.when(
      loading: () => const LoadingIndicator(message: '加载归档项目...'),
      error: (e, _) => Center(
        child: InfoBar(
          title: const Text('加载失败'),
          content: Text(formatUserError(e)),
          severity: InfoBarSeverity.error,
        ),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return const EmptyState(
            icon: FluentIcons.archive,
            title: '没有已归档的项目',
            description: '归档的项目会显示在这里',
          );
        }
        return _buildListView(projects, archived: true);
      },
    );
  }

  Widget _buildSearchResults() {
    final query = _debouncedSearchQuery;
    if (query.isEmpty) {
      return const LoadingIndicator(message: '搜索中...');
    }
    final asyncResults = ref.watch(
      searchProjectsProvider((query, _showArchived)),
    );

    return asyncResults.when(
      loading: () => const LoadingIndicator(message: '搜索中...'),
      error: (e, _) => Center(
        child: InfoBar(
          title: const Text('搜索失败'),
          content: Text(formatUserError(e)),
          severity: InfoBarSeverity.error,
        ),
      ),
      data: (projects) {
        if (projects.isEmpty) {
          return const EmptyState(
            icon: FluentIcons.search,
            title: '未找到匹配项目',
            description: '尝试使用不同的关键词搜索',
          );
        }
        return _effectiveViewMode == _ViewMode.grid
            ? _buildGridView(projects, archived: _showArchived)
            : _buildListView(projects, archived: _showArchived);
      },
    );
  }

  Widget _buildGridView(List<Project> projects, {required bool archived}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount =
            (constraints.maxWidth / 260).floor().clamp(1, 6);
        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: projects.length,
          itemBuilder: (context, index) {
            final project = projects[index];
            return _ProjectCardWithContext(
              project: project,
              archived: archived,
              onTap: () => _onProjectTap(project),
              onEdit: () => _onEdit(project),
              onArchive: archived
                  ? () => _onUnarchive(project)
                  : () => _onArchive(project),
              onDelete: () => _confirmDelete(project),
            );
          },
        );
      },
    );
  }

  Widget _buildListView(List<Project> projects, {required bool archived}) {
    return ListView.builder(
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return _ProjectTileWithContext(
          project: project,
          archived: archived,
          onTap: () => _onProjectTap(project),
          onEdit: () => _onEdit(project),
          onArchive: archived
              ? () => _onUnarchive(project)
              : () => _onArchive(project),
          onDelete: () => _confirmDelete(project),
        );
      },
    );
  }
}

/// Wrapper that fetches per-project asset count for the card.
class _ProjectCardWithContext extends ConsumerWidget {
  const _ProjectCardWithContext({
    required this.project,
    this.archived = false,
    this.onTap,
    this.onEdit,
    this.onArchive,
    this.onDelete,
  });

  final Project project;
  final bool archived;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetCountAsync = ref.watch(
      _assetCountProvider(project.id),
    );

    return _ContextMenuWrapper(
      project: project,
      onTap: onTap,
      onEdit: onEdit,
      onArchive: onArchive,
      onDelete: onDelete,
      child: ProjectCard(
        project: project,
        assetCount: assetCountAsync.value ?? 0,
        archived: archived,
        onTap: onTap,
        onEdit: onEdit,
        onArchive: onArchive,
        onDelete: onDelete,
      ),
    );
  }
}

class _ProjectTileWithContext extends ConsumerWidget {
  const _ProjectTileWithContext({
    required this.project,
    this.archived = false,
    this.onTap,
    this.onEdit,
    this.onArchive,
    this.onDelete,
  });

  final Project project;
  final bool archived;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assetCountAsync = ref.watch(
      _assetCountProvider(project.id),
    );

    return _ContextMenuWrapper(
      project: project,
      onTap: onTap,
      onEdit: onEdit,
      onArchive: onArchive,
      onDelete: onDelete,
      child: ProjectListTile(
        project: project,
        assetCount: assetCountAsync.value ?? 0,
        archived: archived,
        onTap: onTap,
        onEdit: onEdit,
        onArchive: onArchive,
        onDelete: onDelete,
      ),
    );
  }
}

final _assetCountProvider = StreamProvider.autoDispose.family<int, String>((ref, projectId) {
  return ref.watch(assetDaoProvider).watchCountByProject(projectId);
});

/// Right-click context menu wrapper.
class _ContextMenuWrapper extends StatefulWidget {
  const _ContextMenuWrapper({
    required this.project,
    required this.child,
    this.onTap,
    this.onEdit,
    this.onArchive,
    this.onDelete,
  });

  final Project project;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  State<_ContextMenuWrapper> createState() => _ContextMenuWrapperState();
}

class _ContextMenuWrapperState extends State<_ContextMenuWrapper> {
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        _flyoutController.showFlyout(
          navigatorKey: Navigator.of(context, rootNavigator: true),
          position: details.globalPosition,
          barrierDismissible: true,
          builder: (ctx) {
            return MenuFlyout(
              items: [
                MenuFlyoutItem(
                  leading: const Icon(FluentIcons.open_pane),
                  text: const Text('打开'),
                  onPressed: () {
                    Flyout.of(ctx).close();
                    widget.onTap?.call();
                  },
                ),
                MenuFlyoutItem(
                  leading: const Icon(FluentIcons.edit),
                  text: const Text('编辑'),
                  onPressed: () {
                    Flyout.of(ctx).close();
                    widget.onEdit?.call();
                  },
                ),
                MenuFlyoutItem(
                  leading: const Icon(FluentIcons.archive),
                  text: Text(widget.project.isArchived ? '取消归档' : '归档'),
                  onPressed: () {
                    Flyout.of(ctx).close();
                    widget.onArchive?.call();
                  },
                ),
                const MenuFlyoutSeparator(),
                MenuFlyoutItem(
                  leading: Icon(FluentIcons.delete, color: AppColors.error(FluentTheme.of(context).brightness)),
                  text: Text('删除', style: TextStyle(color: AppColors.error(FluentTheme.of(context).brightness))),
                  onPressed: () {
                    Flyout.of(ctx).close();
                    widget.onDelete?.call();
                  },
                ),
              ],
            );
          },
        );
      },
      child: FlyoutTarget(
        controller: _flyoutController,
        child: widget.child,
      ),
    );
  }
}
