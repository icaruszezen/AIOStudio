import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/format_utils.dart';
import '../models/chat_models.dart';

class ChatMessageBubble extends StatefulWidget {
  final ChatMessage message;
  final bool isDarkMode;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.isDarkMode,
  });

  @override
  State<ChatMessageBubble> createState() => _ChatMessageBubbleState();
}

class _ChatMessageBubbleState extends State<ChatMessageBubble> {
  static const _collapsedThreshold = 500;
  bool _isExpanded = false;

  bool get _isUser => widget.message.role == ChatRole.user;
  bool get _isLong =>
      widget.message.content.length > _collapsedThreshold &&
      !widget.message.isStreaming;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment:
            _isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!_isUser) _buildAvatar(theme, isAi: true),
          if (!_isUser) const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: _isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                _buildBubble(theme),
                const SizedBox(height: 4),
                _buildFooter(theme),
              ],
            ),
          ),
          if (_isUser) const SizedBox(width: 8),
          if (_isUser) _buildAvatar(theme, isAi: false),
        ],
      ),
    );
  }

  Widget _buildAvatar(FluentThemeData theme, {required bool isAi}) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isAi
            ? theme.accentColor.defaultBrushFor(theme.brightness)
            : theme.resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        isAi ? FluentIcons.robot : FluentIcons.contact,
        size: 16,
        color: isAi
            ? AppColors.onAccent
            : theme.resources.textFillColorPrimary,
      ),
    );
  }

  Widget _buildBubble(FluentThemeData theme) {
    final hasError = widget.message.error != null;
    final hasImages = widget.message.imagePaths?.isNotEmpty == true;

    Color bgColor;
    if (hasError) {
      bgColor = theme.resources.systemFillColorCriticalBackground;
    } else if (_isUser) {
      bgColor = theme.accentColor.defaultBrushFor(theme.brightness);
    } else {
      bgColor = theme.resources.subtleFillColorSecondary;
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 680),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(12),
          topRight: const Radius.circular(12),
          bottomLeft: Radius.circular(_isUser ? 12 : 2),
          bottomRight: Radius.circular(_isUser ? 2 : 12),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasImages) _buildImagePreviews(),
          if (hasImages && widget.message.content.isNotEmpty)
            const SizedBox(height: 8),
          if (hasError)
            _buildErrorContent(theme)
          else if (_isUser)
            _buildUserContent(theme)
          else
            _buildAssistantContent(theme),
        ],
      ),
    );
  }

  Widget _buildUserContent(FluentThemeData theme) {
    return SelectableText(
      widget.message.content,
      style: theme.typography.body?.copyWith(color: AppColors.onAccent),
    );
  }

  Widget _buildAssistantContent(FluentThemeData theme) {
    final content = widget.message.content;

    if (content.isEmpty && widget.message.isStreaming) {
      return _buildTypingIndicator(theme);
    }

    // During streaming: plain text for performance (no Markdown parsing)
    if (widget.message.isStreaming) {
      return SelectableText(
        '$content\u258D',
        style: theme.typography.body?.copyWith(height: 1.6),
      );
    }

    // Completed: full Markdown rendering
    final displayContent = _isLong && !_isExpanded
        ? '${content.substring(0, _collapsedThreshold)}...'
        : content;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectionArea(
          child: _MarkdownContent(
            data: displayContent,
            isDarkMode: widget.isDarkMode,
          ),
        ),
        if (_isLong)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: HyperlinkButton(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              child: Text(_isExpanded ? '收起' : '展开全部'),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorContent(FluentThemeData theme) {
    return Row(
      children: [
        Icon(FluentIcons.error_badge,
            size: 16, color: AppColors.error(theme.brightness)),
        const SizedBox(width: 8),
        Flexible(
          child: SelectableText(
            widget.message.error!,
            style: theme.typography.body?.copyWith(
              color: AppColors.error(theme.brightness),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator(FluentThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: ProgressRing(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Text('思考中...', style: theme.typography.caption),
      ],
    );
  }

  Widget _buildImagePreviews() {
    final paths = widget.message.imagePaths!;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: paths.map((path) {
        return GestureDetector(
          onTap: () => _showImageDialog(path),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(path),
              width: 120,
              height: 120,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 120,
                height: 120,
                color: FluentTheme.of(context)
                    .resources
                    .subtleFillColorSecondary,
                child: const Icon(FluentIcons.photo2, size: 32),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showImageDialog(String path) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        content: Image.file(
          File(path),
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) =>
              const Center(child: Text('无法加载图片')),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(FluentThemeData theme) {
    final timeStr = formatTime(widget.message.timestamp);
    final tokenInfo = widget.message.totalTokens;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        if (!_isUser && tokenInfo != null) ...[
          const SizedBox(width: 8),
          Text(
            '$tokenInfo tokens',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
        const SizedBox(width: 4),
        _CopyButton(
          content: widget.message.content,
          iconColor: theme.resources.textFillColorSecondary,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Markdown rendering
// ---------------------------------------------------------------------------

class _MarkdownContent extends StatelessWidget {
  final String data;
  final bool isDarkMode;

  const _MarkdownContent({
    required this.data,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    final pStyle = theme.typography.body?.copyWith(height: 1.6) ??
        const TextStyle(fontSize: 14, height: 1.6);

    final config = isDarkMode
        ? MarkdownConfig.darkConfig.copy(configs: [
            PConfig(textStyle: pStyle),
            PreConfig.darkConfig.copy(
              wrapper: (child, code, language) => _CodeBlockWrapper(
                  code: code, language: language, child: child),
            ),
          ])
        : MarkdownConfig.defaultConfig.copy(configs: [
            PConfig(textStyle: pStyle),
            PreConfig(
              wrapper: (child, code, language) => _CodeBlockWrapper(
                  code: code, language: language, child: child),
            ),
          ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: MarkdownGenerator().buildWidgets(data, config: config),
    );
  }
}

class _CodeBlockWrapper extends StatelessWidget {
  final Widget child;
  final String code;
  final String language;

  const _CodeBlockWrapper({
    required this.child,
    required this.code,
    required this.language,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.cardStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorTertiary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                Text(
                  language.isNotEmpty ? language : 'code',
                  style: theme.typography.caption,
                ),
                const Spacer(),
                _CopyButton(
                  content: code,
                  iconColor: theme.resources.textFillColorSecondary,
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared copy button
// ---------------------------------------------------------------------------

class _CopyButton extends StatefulWidget {
  final String content;
  final Color iconColor;

  const _CopyButton({required this.content, required this.iconColor});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  Future<void> _doCopy() async {
    await Clipboard.setData(ClipboardData(text: widget.content));
    if (!mounted) return;
    setState(() => _copied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        _copied ? FluentIcons.check_mark : FluentIcons.copy,
        size: 12,
        color: _copied
            ? AppColors.success(FluentTheme.of(context).brightness)
            : widget.iconColor,
      ),
      onPressed: _doCopy,
    );
  }
}
