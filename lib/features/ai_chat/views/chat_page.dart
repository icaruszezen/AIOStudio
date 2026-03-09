import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/platform_utils.dart';
import '../../../shared/widgets/empty_state.dart';
import '../models/chat_models.dart';
import '../providers/chat_provider.dart';
import '../widgets/chat_input_area.dart';
import '../widgets/chat_message_bubble.dart';
import '../widgets/conversation_list_panel.dart';
import '../widgets/model_selector.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  static const _minListWidth = 240.0;
  static const _maxListFraction = 0.4;

  double _listPanelWidth = 280.0;
  bool _sidebarCollapsed = false;
  final _scrollController = ScrollController();
  final _titleController = TextEditingController();
  bool _editingTitle = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    // Auto-scroll when messages change or streaming
    ref.listen(chatProvider, (prev, next) {
      final prevMsgCount = prev?.currentConversation?.messages.length ?? 0;
      final nextMsgCount = next.currentConversation?.messages.length ?? 0;
      final isStreaming = next.isGenerating;

      if (nextMsgCount > prevMsgCount || isStreaming) {
        _scrollToBottom();
      }
    });

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final isMobileLayout = totalWidth <= Breakpoints.tablet;

          if (isMobileLayout) {
            return _buildChatArea(chatState, isMobileLayout: true);
          }

          final maxListWidth = totalWidth * _maxListFraction;
          final clampedListWidth =
              _listPanelWidth.clamp(_minListWidth, maxListWidth);

          return Row(
            children: [
              if (!_sidebarCollapsed) ...[
                SizedBox(
                  width: clampedListWidth,
                  child: const ConversationListPanel(),
                ),
                _buildDragHandle(totalWidth),
              ],
              Expanded(
                child: _buildChatArea(chatState, isMobileLayout: false),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openMobileConversationDrawer() {
    final theme = FluentTheme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = (screenWidth * 0.85).clamp(240.0, 300.0);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          width: drawerWidth,
          height: double.infinity,
          decoration: BoxDecoration(
            color: theme.micaBackgroundColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Expanded(child: ConversationListPanel()),
                const Divider(),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Button(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(FluentIcons.chrome_back, size: 14),
                        SizedBox(width: 6),
                        Text('关闭'),
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

  Widget _buildChatArea(ChatState chatState, {required bool isMobileLayout}) {
    final conv = chatState.currentConversation;

    if (conv == null) {
      return _buildWelcome(isMobileLayout: isMobileLayout);
    }

    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        isMobileLayout
            ? _buildMobileTopBar(theme, conv, chatState)
            : _buildTopBar(theme, conv, chatState),
        const Divider(),
        Expanded(child: _buildMessageList(conv, isDark)),
        const ChatInputArea(),
      ],
    );
  }

  Widget _buildWelcome({required bool isMobileLayout}) {
    return Column(
      children: [
        if (isMobileLayout)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(FluentIcons.global_nav_button, size: 18),
                onPressed: _openMobileConversationDrawer,
              ),
            ),
          ),
        Expanded(
          child: EmptyState(
            icon: FluentIcons.chat,
            title: '欢迎使用 AI 对话',
            description: isMobileLayout
                ? '点击左上角菜单新建或选择对话'
                : '从左侧新建对话，或选择一个已有对话开始聊天',
            action: FilledButton(
              onPressed: () {
                ref.read(chatProvider.notifier).createConversation();
              },
              child: const Text('开始新对话'),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileTopBar(
    FluentThemeData theme,
    Conversation conv,
    ChatState chatState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(FluentIcons.global_nav_button, size: 18),
                onPressed: _openMobileConversationDrawer,
              ),
              const SizedBox(width: 4),
              Expanded(child: _buildTitle(theme, conv)),
              IconButton(
                icon: Icon(
                  FluentIcons.comment_active,
                  size: 16,
                  color: chatState.systemPrompt.isNotEmpty
                      ? theme.accentColor.defaultBrushFor(theme.brightness)
                      : null,
                ),
                onPressed: () =>
                    _showSystemPromptDialog(chatState.systemPrompt),
              ),
              IconButton(
                icon: const Icon(FluentIcons.delete, size: 16),
                onPressed: () => _confirmDelete(conv),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const SizedBox(
            width: double.infinity,
            child: ModelSelector(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    FluentThemeData theme,
    Conversation conv,
    ChatState chatState,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _sidebarCollapsed
                  ? FluentIcons.open_pane
                  : FluentIcons.close_pane,
              size: 16,
            ),
            onPressed: () =>
                setState(() => _sidebarCollapsed = !_sidebarCollapsed),
          ),
          const SizedBox(width: 8),
          Expanded(child: _buildTitle(theme, conv)),
          const SizedBox(width: 12),
          const ModelSelector(),
          const SizedBox(width: 8),
          Tooltip(
            message: '系统提示词',
            child: IconButton(
              icon: Icon(
                FluentIcons.comment_active,
                size: 16,
                color: chatState.systemPrompt.isNotEmpty
                    ? theme.accentColor.defaultBrushFor(theme.brightness)
                    : null,
              ),
              onPressed: () => _showSystemPromptDialog(chatState.systemPrompt),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: '删除对话',
            child: IconButton(
              icon: const Icon(FluentIcons.delete, size: 16),
              onPressed: () => _confirmDelete(conv),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(FluentThemeData theme, Conversation conv) {
    if (_editingTitle) {
      return SizedBox(
        height: 32,
        child: TextBox(
          controller: _titleController,
          autofocus: true,
          style: theme.typography.bodyStrong,
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) {
              ref
                  .read(chatProvider.notifier)
                  .renameConversation(conv.id, trimmed);
            }
            setState(() => _editingTitle = false);
          },
          suffix: IconButton(
            icon: const Icon(FluentIcons.check_mark, size: 12),
            onPressed: () {
              final trimmed = _titleController.text.trim();
              if (trimmed.isNotEmpty) {
                ref
                    .read(chatProvider.notifier)
                    .renameConversation(conv.id, trimmed);
              }
              setState(() => _editingTitle = false);
            },
          ),
        ),
      );
    }

    return GestureDetector(
      onDoubleTap: () {
        _titleController.text = conv.title;
        setState(() => _editingTitle = true);
      },
      child: Text(
        conv.title,
        style: theme.typography.bodyStrong,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMessageList(Conversation conv, bool isDark) {
    final messages = conv.messages;

    if (messages.isEmpty) {
      return const EmptyState(
        icon: FluentIcons.message,
        title: '开始对话',
        description: '在下方输入消息，开始与 AI 聊天',
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return ChatMessageBubble(
          key: ValueKey(messages[index].id),
          message: messages[index],
          isDarkMode: isDark,
        );
      },
    );
  }

  Future<void> _showSystemPromptDialog(String currentPrompt) async {
    final controller = TextEditingController(text: currentPrompt);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('系统提示词'),
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 400),
        content: TextBox(
          controller: controller,
          maxLines: 10,
          placeholder: '输入系统提示词（可选）...\n\n例如：你是一个有帮助的 AI 助手。',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('保存'),
          ),
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null) {
      ref.read(chatProvider.notifier).setSystemPrompt(result);
    }
  }

  Future<void> _confirmDelete(Conversation conv) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('删除对话'),
        content: const Text('确定要删除当前对话吗？此操作不可撤销。'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(AppColors.error(FluentTheme.of(context).brightness)),
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
    if (confirmed == true) {
      ref.read(chatProvider.notifier).deleteConversation(conv.id);
    }
  }
}
