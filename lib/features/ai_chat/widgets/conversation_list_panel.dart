import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';

class ConversationListPanel extends ConsumerStatefulWidget {
  const ConversationListPanel({super.key});

  @override
  ConsumerState<ConversationListPanel> createState() =>
      _ConversationListPanelState();
}

class _ConversationListPanelState
    extends ConsumerState<ConversationListPanel> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final chatState = ref.watch(chatProvider);
    final allConversations = chatState.conversations;

    final filtered = _searchQuery.isEmpty
        ? allConversations
        : allConversations
            .where((c) =>
                c.title.toLowerCase().contains(_searchQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        _buildHeader(theme),
        if (allConversations.length > 5) _buildSearchBox(theme),
        const Divider(),
        Expanded(
          child: filtered.isEmpty
              ? EmptyState(
                  icon: FluentIcons.chat,
                  title: _searchQuery.isEmpty ? '暂无对话' : '无匹配结果',
                  description: _searchQuery.isEmpty
                      ? '点击"新建对话"开始聊天'
                      : '尝试其他关键词',
                )
              : _buildList(filtered, chatState.currentConversationId),
        ),
      ],
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Text('对话列表', style: theme.typography.subtitle),
          const Spacer(),
          FilledButton(
            onPressed: () {
              ref.read(chatProvider.notifier).createConversation();
            },
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.add, size: 12),
                SizedBox(width: 6),
                Text('新建对话'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: TextBox(
        controller: _searchController,
        placeholder: '搜索对话...',
        prefix: const Padding(
          padding: EdgeInsets.only(left: 8),
          child: Icon(FluentIcons.search, size: 14),
        ),
        suffix: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(FluentIcons.clear, size: 10),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  Widget _buildList(List<Conversation> conversations, String? currentId) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conv = conversations[index];
        final isSelected = conv.id == currentId;
        return _ConversationTile(
          key: ValueKey(conv.id),
          conversation: conv,
          isSelected: isSelected,
          onTap: () {
            ref.read(chatProvider.notifier).selectConversation(conv.id);
          },
          onRename: () => _showRenameDialog(conv),
          onDelete: () => _confirmDelete(conv),
        );
      },
    );
  }

  Future<void> _showRenameDialog(Conversation conv) async {
    final controller = TextEditingController(text: conv.title);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('重命名对话'),
        content: TextBox(
          controller: controller,
          placeholder: '输入新标题',
          autofocus: true,
        ),
        actions: [
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('确定'),
          ),
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (result != null && result.isNotEmpty) {
      ref.read(chatProvider.notifier).renameConversation(conv.id, result);
    }
  }

  Future<void> _confirmDelete(Conversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除对话「${conv.title}」吗？此操作不可撤销。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(
                  AppColors.error(FluentTheme.of(context).brightness)),
            ),
            child: const Text('删除'),
          ),
          Button(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (confirmed == true) {
      ref.read(chatProvider.notifier).deleteConversation(conv.id);
    }
  }
}

// ---------------------------------------------------------------------------
// Conversation tile
// ---------------------------------------------------------------------------

class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _ConversationTile({
    super.key,
    required this.conversation,
    required this.isSelected,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  void _showContextMenu(BuildContext context, {required Offset position}) {
    _flyoutController.showFlyout(
      navigatorKey: Navigator.of(context, rootNavigator: true),
      position: position,
      barrierDismissible: true,
      builder: (ctx) {
        final theme = FluentTheme.of(context);
        return MenuFlyout(
          items: [
            MenuFlyoutItem(
              leading: const Icon(FluentIcons.rename, size: 14),
              text: const Text('重命名'),
              onPressed: widget.onRename,
            ),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: Icon(FluentIcons.delete,
                  size: 14, color: AppColors.error(theme.brightness)),
              text: Text('删除',
                  style:
                      TextStyle(color: AppColors.error(theme.brightness))),
              onPressed: widget.onDelete,
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final conv = widget.conversation;
    final lastMsg = conv.lastMessage;
    final timeStr = DateFormat('MM/dd HH:mm').format(conv.updatedAt);

    return FlyoutTarget(
      controller: _flyoutController,
      child: GestureDetector(
        onTap: widget.onTap,
        onLongPressStart: (details) =>
            _showContextMenu(context, position: details.globalPosition),
        onSecondaryTapUp: (details) =>
            _showContextMenu(context, position: details.globalPosition),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? theme.accentColor
                    .defaultBrushFor(theme.brightness)
                    .withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      conv.title,
                      style: theme.typography.body?.copyWith(
                        fontWeight: widget.isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ],
              ),
              if (lastMsg != null) ...[
                const SizedBox(height: 4),
                Text(
                  lastMsg.content.isNotEmpty
                      ? lastMsg.content.replaceAll('\n', ' ')
                      : (lastMsg.error ?? ''),
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
