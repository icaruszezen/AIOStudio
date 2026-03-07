import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/tags_provider.dart';

/// Inline tag editor: shows current tags as chips with an add button.
class AssetTagEditor extends ConsumerStatefulWidget {
  const AssetTagEditor({
    super.key,
    required this.assetId,
  });

  final String assetId;

  @override
  ConsumerState<AssetTagEditor> createState() => _AssetTagEditorState();
}

class _AssetTagEditorState extends ConsumerState<AssetTagEditor> {
  bool _isAdding = false;
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final assetTagsAsync = ref.watch(tagsForAssetProvider(widget.assetId));

    return assetTagsAsync.when(
      loading: () => const SizedBox(
        height: 28,
        child: Center(child: ProgressRing(strokeWidth: 2)),
      ),
      error: (e, _) => Text('$e', style: TextStyle(color: AppColors.error(theme.brightness))),
      data: (currentTags) {
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final tag in currentTags) _buildTagChip(theme, tag),
            if (_isAdding)
              _buildAddInput(theme, currentTags)
            else
              _buildAddButton(theme),
          ],
        );
      },
    );
  }

  Widget _buildTagChip(FluentThemeData theme, Tag tag) {
    final chipColor =
        tag.color != null ? Color(tag.color!) : theme.accentColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: chipColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            tag.name,
            style: theme.typography.caption?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _removeTag(tag.id),
            child: Icon(
              FluentIcons.chrome_close,
              size: 10,
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(FluentThemeData theme) {
    return GestureDetector(
      onTap: () => setState(() => _isAdding = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.resources.cardStrokeColorDefault,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.add,
              size: 10,
              color: theme.resources.textFillColorSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '添加标签',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddInput(FluentThemeData theme, List<Tag> currentTags) {
    final allTagsAsync = ref.watch(allTagsProvider);
    final allTags = allTagsAsync.value ?? <Tag>[];
    final currentTagIds = currentTags.map((t) => t.id).toSet();
    final available =
        allTags.where((t) => !currentTagIds.contains(t.id)).toList();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 140,
          height: 28,
          child: AutoSuggestBox<Tag>(
            controller: _textController,
            placeholder: '输入标签名...',
            items: available
                .map((t) => AutoSuggestBoxItem<Tag>(
                      value: t,
                      label: t.name,
                    ))
                .toList(),
            onSelected: (item) {
              if (item.value != null) {
                _addExistingTag(item.value!.id);
              }
            },
            trailingIcon: GestureDetector(
              onTap: () => setState(() {
                _isAdding = false;
                _textController.clear();
              }),
              child: const Icon(FluentIcons.chrome_close, size: 10),
            ),
          ),
        ),
        const SizedBox(width: 4),
        SizedBox(
          height: 28,
          child: IconButton(
            icon: const Icon(FluentIcons.check_mark, size: 12),
            onPressed: () {
              final text = _textController.text.trim();
              if (text.isEmpty) return;
              final match = available.where(
                (t) => t.name.toLowerCase() == text.toLowerCase(),
              );
              if (match.isNotEmpty) {
                _addExistingTag(match.first.id);
              } else {
                _createAndAddTag(text);
              }
            },
          ),
        ),
      ],
    );
  }

  Future<void> _addExistingTag(String tagId) async {
    await ref.read(tagActionsProvider).addToAsset(widget.assetId, tagId);
    setState(() {
      _isAdding = false;
      _textController.clear();
    });
  }

  Future<void> _createAndAddTag(String name) async {
    final actions = ref.read(tagActionsProvider);
    final tagId = await actions.create(name: name.trim());
    await actions.addToAsset(widget.assetId, tagId);
    setState(() {
      _isAdding = false;
      _textController.clear();
    });
  }

  Future<void> _removeTag(String tagId) async {
    await ref.read(tagActionsProvider).removeFromAsset(widget.assetId, tagId);
  }
}

/// Tag selector panel for filtering (multiple selection).
class TagSelectorPanel extends ConsumerWidget {
  const TagSelectorPanel({
    super.key,
    required this.selectedTagIds,
    required this.onToggle,
  });

  final Set<String> selectedTagIds;
  final void Function(String tagId) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final tagsAsync = ref.watch(allTagsProvider);

    return tagsAsync.when(
      loading: () => const Center(child: ProgressRing(strokeWidth: 2)),
      error: (e, _) => Text('$e'),
      data: (tags) {
        if (tags.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              '暂无标签',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          );
        }
        return Wrap(
          spacing: 6,
          runSpacing: 6,
          children: tags.map((tag) {
            final isSelected = selectedTagIds.contains(tag.id);
            final chipColor = tag.color != null
                ? Color(tag.color!)
                : theme.accentColor;

            return GestureDetector(
              onTap: () => onToggle(tag.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? chipColor.withValues(alpha: 0.2)
                      : theme.resources.subtleFillColorSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? chipColor
                        : theme.resources.cardStrokeColorDefault,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: chipColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tag.name,
                      style: theme.typography.caption?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      Icon(
                        FluentIcons.check_mark,
                        size: 10,
                        color: chipColor,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
