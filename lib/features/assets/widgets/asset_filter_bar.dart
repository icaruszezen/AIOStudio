import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/design_tokens.dart';
import '../providers/asset_filter_provider.dart';
import '../providers/tags_provider.dart';
import 'asset_type_helpers.dart';

class AssetFilterBar extends ConsumerWidget {
  const AssetFilterBar({super.key, this.projects = const []});

  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final filter = ref.watch(assetFilterProvider);
    final notifier = ref.read(assetFilterProvider.notifier);
    final allTags = ref.watch(allTagsProvider).value ?? <Tag>[];

    if (!filter.hasActiveFilters) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingXL,
        0,
        DesignTokens.spacingXL,
        DesignTokens.spacingSM,
      ),
      child: Row(
        children: [
          Icon(
            FluentIcons.filter,
            size: DesignTokens.iconXS,
            color: theme.resources.textFillColorSecondary,
          ),
          const SizedBox(width: DesignTokens.spacingSM),
          Expanded(
            child: Wrap(
              spacing: 6,
              runSpacing: DesignTokens.spacingXS,
              children: [
                if (filter.typeFilter != null)
                  _FilterChip(
                    label: '类型: ${assetTypeLabel(filter.typeFilter!)}',
                    onRemove: () => notifier.setTypeFilter(null),
                  ),
                if (filter.projectFilter != null)
                  _FilterChip(
                    label:
                        '项目: ${_projectName(filter.projectFilter!, projects)}',
                    onRemove: () => notifier.setProjectFilter(null),
                  ),
                for (final tagId in filter.tagFilters)
                  _FilterChip(
                    label: '标签: ${_tagName(tagId, allTags)}',
                    onRemove: () => notifier.removeTagFilter(tagId),
                  ),
                if (filter.searchQuery.isNotEmpty)
                  _FilterChip(
                    label: '搜索: "${filter.searchQuery}"',
                    onRemove: () => notifier.setSearchQuery(''),
                  ),
              ],
            ),
          ),
          const SizedBox(width: DesignTokens.spacingSM),
          HyperlinkButton(
            onPressed: () => notifier.clearAll(),
            child: const Text('清除全部'),
          ),
        ],
      ),
    );
  }

  static String _projectName(String id, List<Project> projects) {
    final match = projects.where((p) => p.id == id);
    return match.isNotEmpty ? match.first.name : id;
  }

  static String _tagName(String id, List<Tag> tags) {
    final match = tags.where((t) => t.id == id);
    return match.isNotEmpty ? match.first.name : id;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: DesignTokens.spacingSM,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: DesignTokens.borderRadiusXL,
        border: Border.all(color: theme.accentColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.typography.caption?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: DesignTokens.spacingXS),
          GestureDetector(
            onTap: onRemove,
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
}
