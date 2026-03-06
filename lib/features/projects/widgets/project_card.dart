// Uses dart:io (File / Image.file) -- desktop & mobile only; not web-compatible.
import 'dart:io';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';

class ProjectCard extends StatefulWidget {
  const ProjectCard({
    super.key,
    required this.project,
    this.assetCount = 0,
    this.onTap,
    this.onEdit,
    this.onArchive,
    this.onDelete,
  });

  final Project project;
  final int assetCount;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _isHovered = false;

  static const _gradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    [Color(0xFF10B981), Color(0xFF34D399)],
    [Color(0xFFF59E0B), Color(0xFFF97316)],
    [Color(0xFFEF4444), Color(0xFFF472B6)],
    [Color(0xFF8B5CF6), Color(0xFFEC4899)],
  ];

  List<Color> _gradientForProject(String name) {
    final index = name.hashCode.abs() % _gradients.length;
    return _gradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final project = widget.project;
    final updatedAt = DateTime.fromMillisecondsSinceEpoch(project.updatedAt);
    final dateStr = DateFormat('yyyy-MM-dd').format(updatedAt);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered
                  ? theme.accentColor.withValues(alpha: 0.5)
                  : theme.resources.cardStrokeColorDefault,
            ),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: theme.accentColor.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCover(theme, project),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
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
                          project.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          project.description!,
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      Row(
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
                          const Spacer(),
                          Text(
                            dateStr,
                            style: theme.typography.caption?.copyWith(
                              color: theme.resources.textFillColorTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCover(FluentThemeData theme, Project project) {
    const height = 120.0;
    final hasCover =
        project.coverImagePath != null && project.coverImagePath!.isNotEmpty;

    Widget cover;
    if (hasCover) {
      cover = Image.file(
        File(project.coverImagePath!),
        height: height,
        width: double.infinity,
        fit: BoxFit.cover,
        cacheWidth: 400,
        errorBuilder: (_, __, ___) => _buildGradientPlaceholder(project, height),
      );
    } else {
      cover = _buildGradientPlaceholder(project, height);
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          child: cover,
        ),
        if (_isHovered)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(6)),
              child: Container(
                height: height,
                color: Colors.black.withValues(alpha: 0.4),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HoverIconButton(
                        icon: FluentIcons.edit,
                        tooltip: '编辑',
                        onPressed: widget.onEdit,
                      ),
                      const SizedBox(width: 8),
                      _HoverIconButton(
                        icon: FluentIcons.archive,
                        tooltip: '归档',
                        onPressed: widget.onArchive,
                      ),
                      const SizedBox(width: 8),
                      _HoverIconButton(
                        icon: FluentIcons.delete,
                        tooltip: '删除',
                        onPressed: widget.onDelete,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGradientPlaceholder(Project project, double height) {
    final colors = _gradientForProject(project.name);
    final initial = project.name.isNotEmpty ? project.name[0].toUpperCase() : '?';
    return Container(
      height: height,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          transform: GradientRotation(
            (project.name.hashCode % 360) * math.pi / 180,
          ),
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _HoverIconButton extends StatelessWidget {
  const _HoverIconButton({
    required this.icon,
    required this.tooltip,
    this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 16, color: Colors.white),
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.isPressed) return Colors.white.withValues(alpha: 0.3);
            if (states.isHovered) return Colors.white.withValues(alpha: 0.2);
            return Colors.white.withValues(alpha: 0.1);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      ),
    );
  }
}
