import 'dart:ui' show PointerDeviceKind;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/prompts_provider.dart';
import '../widgets/prompt_card.dart';
import 'prompt_editor_page.dart';

class PromptsPage extends ConsumerStatefulWidget {
  const PromptsPage({super.key});

  @override
  ConsumerState<PromptsPage> createState() => _PromptsPageState();
}

class _PromptsPageState extends ConsumerState<PromptsPage> {
  static const _minListWidth = 280.0;
  static const _maxListFraction = 0.5;

  double _listPanelWidth = 360.0;
  int _selectedTabIndex = 0;
  final _searchController = TextEditingController();
  final _tabScrollController = ScrollController();

  static final _categoryTabs = <String?>[
    null,
    ...promptCategories.map((c) => c.value),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    setState(() => _selectedTabIndex = index);
    final category = _categoryTabs[index];
    ref.read(promptCategoryFilterProvider.notifier).set(category);
  }

  Future<void> _createPrompt() async {
    final id = await ref.read(promptActionsProvider).createPrompt(
          title: '新提示词',
          content: '',
          category: _categoryTabs[_selectedTabIndex],
        );
    ref.read(currentPromptIdProvider.notifier).select(id);
  }

  void _onSearchChanged(String query) {
    ref.read(promptSearchQueryProvider.notifier).set(query);
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final maxListWidth = totalWidth * _maxListFraction;
          final clampedListWidth =
              _listPanelWidth.clamp(_minListWidth, maxListWidth);

          return Row(
            children: [
              SizedBox(
                width: clampedListWidth,
                child: _buildListPanel(),
              ),
              _buildDragHandle(totalWidth),
              Expanded(child: _buildEditorPanel()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDragHandle(double totalWidth) {
    final theme = FluentTheme.of(context);
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _listPanelWidth += details.delta.dx;
          final maxW = totalWidth * _maxListFraction;
          _listPanelWidth = _listPanelWidth.clamp(_minListWidth, maxW);
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

  Widget _buildListPanel() {
    final theme = FluentTheme.of(context);

    return Column(
      children: [
        _buildListHeader(theme),
        _buildCategoryTabs(theme),
        Expanded(child: _buildPromptList()),
      ],
    );
  }

  Widget _buildListHeader(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Text('提示词库', style: theme.typography.subtitle),
              const Spacer(),
              FilledButton(
                onPressed: _createPrompt,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.add, size: 12),
                    SizedBox(width: 6),
                    Text('新建'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextBox(
            controller: _searchController,
            placeholder: '搜索提示词...',
            prefix: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(FluentIcons.search, size: 14),
            ),
            suffix: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(FluentIcons.clear, size: 12),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : null,
            onChanged: _onSearchChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs(FluentThemeData theme) {
    final tabLabels = [
      '全部',
      ...promptCategories.map((c) => c.label),
    ];
    return SizedBox(
      height: 36,
      child: Listener(
        onPointerSignal: (event) {
          if (event is PointerScrollEvent &&
              _tabScrollController.hasClients) {
            _tabScrollController.jumpTo(
              (_tabScrollController.offset + event.scrollDelta.dy).clamp(
                0.0,
                _tabScrollController.position.maxScrollExtent,
              ),
            );
          }
        },
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
            },
            scrollbars: false,
          ),
          child: ListView.builder(
            controller: _tabScrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: tabLabels.length,
            itemBuilder: (context, index) {
              final isSelected = _selectedTabIndex == index;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: SizedBox(
                  height: 32,
                  child: ToggleButton(
                    checked: isSelected,
                    onChanged: (_) => _onTabChanged(index),
                    child: Text(
                      tabLabels[index],
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPromptList() {
    final promptsAsync = ref.watch(filteredPromptsProvider);
    final selectedId = ref.watch(currentPromptIdProvider);

    return promptsAsync.when(
      loading: () => const LoadingIndicator(),
      error: (e, _) => Center(child: Text('加载失败: $e')),
      data: (prompts) {
        if (prompts.isEmpty) {
          return EmptyState(
            icon: FluentIcons.text_document,
            title: '暂无提示词',
            description: '点击"新建"按钮创建你的第一个提示词',
            action: FilledButton(
              onPressed: _createPrompt,
              child: const Text('新建提示词'),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: prompts.length,
          itemBuilder: (context, index) {
            final prompt = prompts[index];
            return PromptCard(
              prompt: prompt,
              isSelected: prompt.id == selectedId,
              onTap: () {
                ref.read(currentPromptIdProvider.notifier).select(prompt.id);
              },
              onFavoriteToggle: () {
                ref.read(promptActionsProvider).toggleFavorite(prompt.id);
              },
              onDelete: () => _confirmDelete(prompt),
              onDuplicate: () async {
                final newId = await ref
                    .read(promptActionsProvider)
                    .duplicatePrompt(prompt.id);
                ref.read(currentPromptIdProvider.notifier).select(newId);
              },
              onCopyContent: () {
                Clipboard.setData(ClipboardData(text: prompt.content));
                displayInfoBar(context, builder: (_, close) {
                  return InfoBar(
                    title: const Text('已复制到剪贴板'),
                    severity: InfoBarSeverity.success,
                    action: IconButton(
                      icon: const Icon(FluentIcons.clear),
                      onPressed: close,
                    ),
                  );
                });
              },
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDelete(Prompt prompt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final theme = FluentTheme.of(ctx);
        return ContentDialog(
          title: const Text('确认删除'),
          content: Text('确定要删除提示词「${prompt.title}」吗？此操作不可撤销。'),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ButtonStyle(
                backgroundColor: WidgetStatePropertyAll(AppColors.error(theme.brightness)),
              ),
              child: const Text('删除'),
            ),
            Button(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await ref.read(promptActionsProvider).deletePrompt(prompt.id);
    }
  }

  Widget _buildEditorPanel() {
    final selectedId = ref.watch(currentPromptIdProvider);

    if (selectedId == null) {
      return const EmptyState(
        icon: FluentIcons.edit_note,
        title: '选择一个提示词',
        description: '从左侧列表中选择一个提示词进行编辑，或创建新的提示词',
      );
    }

    return PromptEditorPanel(
      key: ValueKey(selectedId),
      promptId: selectedId,
    );
  }
}
