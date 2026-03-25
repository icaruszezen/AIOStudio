import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/error_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../../prompts/providers/prompts_provider.dart';
import '../../prompts/widgets/prompt_card.dart';

class ProjectPromptsTab extends ConsumerStatefulWidget {
  const ProjectPromptsTab({super.key, required this.projectId});

  final String projectId;

  @override
  ConsumerState<ProjectPromptsTab> createState() => _ProjectPromptsTabState();
}

class _ProjectPromptsTabState extends ConsumerState<ProjectPromptsTab> {
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final promptsAsync =
        ref.watch(promptsByProjectProvider(widget.projectId));

    return Column(
      children: [
        _buildToolbar(theme),
        const Divider(),
        Expanded(
          child: promptsAsync.when(
            loading: () => const LoadingIndicator(message: '加载提示词...'),
            error: (e, _) => Center(
              child: InfoBar(
                title: const Text('加载失败'),
                content: Text(formatUserError(e)),
                severity: InfoBarSeverity.error,
              ),
            ),
            data: (prompts) {
              if (prompts.isEmpty) {
                return EmptyState(
                  icon: FluentIcons.text_document,
                  title: '暂无提示词',
                  description: '为此项目创建提示词',
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
                    onTap: () => _navigateToPrompt(prompt.id),
                    onFavoriteToggle: () => ref
                        .read(promptActionsProvider)
                        .toggleFavorite(prompt.id),
                    onDelete: () => _confirmDelete(prompt),
                    onDuplicate: () => ref
                        .read(promptActionsProvider)
                        .duplicatePrompt(prompt.id),
                    onCopyContent: () => _copyContent(prompt.content),
                  );
                },
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
          const Spacer(),
          HyperlinkButton(
            onPressed: () => context.go(AppRoutes.prompts),
            child: const Text('查看全部'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _createPrompt,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.add, size: 14),
                SizedBox(width: 6),
                Text('新建'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createPrompt() async {
    final id = await ref.read(promptActionsProvider).createPrompt(
          title: '新提示词',
          content: '',
          projectId: widget.projectId,
        );
    if (mounted) _navigateToPrompt(id);
  }

  void _navigateToPrompt(String promptId) {
    ref.read(currentPromptIdProvider.notifier).select(promptId);
    context.go(AppRoutes.prompts);
  }

  void _copyContent(String content) {
    Clipboard.setData(ClipboardData(text: content));
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
  }

  Future<void> _confirmDelete(Prompt prompt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除提示词「${prompt.title}」吗？此操作不可撤销。'),
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
      await ref.read(promptActionsProvider).deletePrompt(prompt.id);
    }
  }
}
