import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/utils/format_utils.dart';

class ProjectListTile extends StatefulWidget {
  const ProjectListTile({
    super.key,
    required this.project,
    this.assetCount = 0,
    this.archived = false,
    this.onTap,
    this.onEdit,
    this.onArchive,
    this.onDelete,
  });

  final Project project;
  final int assetCount;
  final bool archived;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  State<ProjectListTile> createState() => _ProjectListTileState();
}

class _ProjectListTileState extends State<ProjectListTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final project = widget.project;
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(project.updatedAt);
    final dateStr = formatDateTime(updatedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _isHovered
                ? theme.resources.subtleFillColorSecondary
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(
                FluentIcons.project_management,
                size: 20,
                color: theme.accentColor,
              ),
              const SizedBox(width: 14),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.name,
                      style: theme.typography.bodyStrong,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (project.description != null &&
                        project.description!.isNotEmpty)
                      Text(
                        project.description!,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 60,
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.photo_collection,
                      size: 12,
                      color: theme.resources.textFillColorSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.assetCount}',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 130,
                child: Text(
                  dateStr,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorTertiary,
                  ),
                ),
              ),
              if (_isHovered) ...[
                Tooltip(
                  message: '编辑',
                  child: IconButton(
                    icon: const Icon(FluentIcons.edit, size: 14),
                    onPressed: widget.onEdit,
                  ),
                ),
                Tooltip(
                  message: widget.archived ? '取消归档' : '归档',
                  child: IconButton(
                    icon: Icon(
                      widget.archived
                          ? FluentIcons.archive_undo
                          : FluentIcons.archive,
                      size: 14,
                    ),
                    onPressed: widget.onArchive,
                  ),
                ),
                Tooltip(
                  message: '删除',
                  child: IconButton(
                    icon: const Icon(FluentIcons.delete, size: 14),
                    onPressed: widget.onDelete,
                  ),
                ),
              ] else
                const SizedBox(width: 96),
            ],
          ),
        ),
      ),
    );
  }
}
