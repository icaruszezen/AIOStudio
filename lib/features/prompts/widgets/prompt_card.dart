import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/database/app_database.dart';
import 'prompt_context_menu.dart';

IconData promptCategoryIcon(String? category) {
  return switch (category) {
    'text_gen' => FluentIcons.text_document,
    'image_gen' => FluentIcons.photo2,
    'video_gen' => FluentIcons.video,
    'optimization' => FluentIcons.auto_enhance_on,
    'other' => FluentIcons.more,
    _ => FluentIcons.text_document,
  };
}

Color promptCategoryColor(String? category, [Brightness brightness = Brightness.light]) {
  final isDark = brightness == Brightness.dark;
  return switch (category) {
    'text_gen' => isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6),
    'image_gen' => isDark ? const Color(0xFFA78BFA) : const Color(0xFF8B5CF6),
    'video_gen' => isDark ? const Color(0xFFF87171) : const Color(0xFFEF4444),
    'optimization' => isDark ? const Color(0xFF34D399) : const Color(0xFF10B981),
    'other' => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
    _ => isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
  };
}

class PromptCard extends StatefulWidget {
  const PromptCard({
    super.key,
    required this.prompt,
    this.isSelected = false,
    this.onTap,
    this.onFavoriteToggle,
    this.onDelete,
    this.onDuplicate,
    this.onCopyContent,
  });

  final Prompt prompt;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onDelete;
  final VoidCallback? onDuplicate;
  final VoidCallback? onCopyContent;

  @override
  State<PromptCard> createState() => _PromptCardState();
}

class _PromptCardState extends State<PromptCard> {
  bool _isHovered = false;
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final catColor = promptCategoryColor(widget.prompt.category, theme.brightness);

    return GestureDetector(
      onTap: widget.onTap,
      onSecondaryTapUp: (details) => _showContextMenu(context, details),
      child: FlyoutTarget(
        controller: _flyoutController,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: widget.isSelected
                  ? theme.accentColor.withValues(alpha: 0.1)
                  : _isHovered
                      ? theme.resources.subtleFillColorSecondary
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: widget.isSelected
                  ? Border.all(
                      color: theme.accentColor.withValues(alpha: 0.4))
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: catColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    promptCategoryIcon(widget.prompt.category),
                    size: 14,
                    color: catColor,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.prompt.title,
                        style: theme.typography.body?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.prompt.content,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (widget.prompt.useCount > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.resources.subtleFillColorSecondary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${widget.prompt.useCount}',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
                if (widget.prompt.isFavorite)
                  const Padding(
                    padding: EdgeInsets.only(left: 2),
                    child: Icon(
                      FluentIcons.heart_fill,
                      size: 12,
                      color: Color(0xFFEF4444),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, TapUpDetails details) {
    showPromptContextMenu(
      context: context,
      controller: _flyoutController,
      position: details.localPosition,
      prompt: widget.prompt,
      onFavoriteToggle: widget.onFavoriteToggle,
      onDelete: widget.onDelete,
      onDuplicate: widget.onDuplicate,
      onCopyContent: widget.onCopyContent,
    );
  }
}
