// Uses dart:io (File / Image.file) -- desktop & mobile only; not web-compatible.
import 'dart:io';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/utils/format_utils.dart';

class ProjectCard extends StatefulWidget {
  const ProjectCard({
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
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  bool _isHovered = false;

  List<Color> _gradientForProject(String name) {
    final index = name.hashCode.abs() % AppColors.projectGradients.length;
    return AppColors.projectGradients[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final project = widget.project;
    final dateStr = formatDate(
      DateTime.fromMillisecondsSinceEpoch(project.updatedAt),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: _buildCardDecoration(theme),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildCover(project),
              Expanded(child: _buildDetailsSection(theme, project, dateStr)),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildCardDecoration(FluentThemeData theme) {
    return BoxDecoration(
      color: theme.cardColor,
      borderRadius: DesignTokens.borderRadiusMD,
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
    );
  }

  Widget _buildDetailsSection(
    FluentThemeData theme,
    Project project,
    String dateStr,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DesignTokens.spacingMD,
        10,
        DesignTokens.spacingMD,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitleAndDescription(theme, project),
          const Spacer(),
          _buildMetadataRow(theme, dateStr),
        ],
      ),
    );
  }

  Widget _buildTitleAndDescription(FluentThemeData theme, Project project) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          project.name,
          style: theme.typography.bodyStrong,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (project.description != null && project.description!.isNotEmpty) ...[
          const SizedBox(height: DesignTokens.spacingXS),
          Text(
            project.description!,
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildMetadataRow(FluentThemeData theme, String dateStr) {
    return Row(
      children: [
        Icon(
          FluentIcons.photo_collection,
          size: DesignTokens.iconXS,
          color: theme.resources.textFillColorSecondary,
        ),
        const SizedBox(width: DesignTokens.spacingXS),
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
    );
  }

  Widget _buildCover(Project project) {
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
        errorBuilder: (_, __, ___) =>
            _buildGradientPlaceholder(project, height),
      );
    } else {
      cover = _buildGradientPlaceholder(project, height);
    }

    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(DesignTokens.radiusMD),
          ),
          child: cover,
        ),
        if (_isHovered) _buildCoverHoverOverlay(height),
      ],
    );
  }

  Widget _buildCoverHoverOverlay(double height) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(DesignTokens.radiusMD),
        ),
        child: Container(
          height: height,
          color: AppColors.overlayDark(0.4),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HoverIconButton(
                  icon: FluentIcons.edit,
                  tooltip: '编辑',
                  onPressed: widget.onEdit,
                ),
                const SizedBox(width: DesignTokens.spacingSM),
                _HoverIconButton(
                  icon: widget.archived
                      ? FluentIcons.archive_undo
                      : FluentIcons.archive,
                  tooltip: widget.archived ? '取消归档' : '归档',
                  onPressed: widget.onArchive,
                ),
                const SizedBox(width: DesignTokens.spacingSM),
                _HoverIconButton(
                  icon: FluentIcons.delete,
                  tooltip: '删除',
                  onPressed: widget.onDelete,
                  danger: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientPlaceholder(Project project, double height) {
    final colors = _gradientForProject(project.name);
    final initial = project.name.isNotEmpty
        ? project.name[0].toUpperCase()
        : '?';
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
            color: AppColors.onAccent,
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
    this.danger = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final iconColor = danger
        ? AppColors.error(FluentTheme.of(context).brightness)
        : AppColors.onAccent;
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: DesignTokens.iconMD, color: iconColor),
        onPressed: onPressed,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.isPressed) return AppColors.overlayLight(0.3);
            if (states.isHovered) return AppColors.overlayLight(0.2);
            return AppColors.overlayLight(0.1);
          }),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: DesignTokens.borderRadiusSM),
          ),
        ),
      ),
    );
  }
}
