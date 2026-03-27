import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/error_utils.dart';
import '../providers/tags_provider.dart';
import 'asset_tag_editor.dart';

// ---------------------------------------------------------------------------
// Tag filter flyout button
// ---------------------------------------------------------------------------

class TagFilterButton extends StatefulWidget {
  const TagFilterButton({
    super.key,
    required this.selectedTagIds,
    required this.onToggle,
  });

  final Set<String> selectedTagIds;
  final void Function(String tagId) onToggle;

  @override
  State<TagFilterButton> createState() => _TagFilterButtonState();
}

class _TagFilterButtonState extends State<TagFilterButton> {
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
            Text(
              '标签${widget.selectedTagIds.isNotEmpty ? ' (${widget.selectedTagIds.length})' : ''}',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Batch tag selector (used in dialog)
// ---------------------------------------------------------------------------

class BatchTagSelector extends ConsumerWidget {
  const BatchTagSelector({super.key, required this.assetIds});

  final List<String> assetIds;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final tagsAsync = ref.watch(allTagsProvider);

    return tagsAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Text(formatUserError(e)),
      data: (tags) {
        if (tags.isEmpty) {
          return Text('暂无标签，请先创建标签', style: theme.typography.body);
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
                      title: Text(
                        '已为 ${assetIds.length} 个资产添加标签 "${tag.name}"',
                      ),
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

// ---------------------------------------------------------------------------
// Mobile bottom action button
// ---------------------------------------------------------------------------

class MobileActionButton extends StatelessWidget {
  const MobileActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final color = isDestructive
        ? AppColors.error(theme.brightness)
        : theme.resources.textFillColorPrimary;

    return GestureDetector(
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.typography.caption?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
