// Uses dart:io (File / Image.file) -- desktop & mobile only; not web-compatible.
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/projects_provider.dart';

class ProjectCreateDialog extends ConsumerStatefulWidget {
  const ProjectCreateDialog({super.key, this.existing});

  final Project? existing;

  static Future<bool?> show(
    BuildContext context, {
    Project? existing,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => ProjectCreateDialog(existing: existing),
    );
  }

  @override
  ConsumerState<ProjectCreateDialog> createState() =>
      _ProjectCreateDialogState();
}

class _ProjectCreateDialogState extends ConsumerState<ProjectCreateDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  String? _coverPath;
  String? _nameError;
  bool _isSubmitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _descController =
        TextEditingController(text: widget.existing?.description ?? '');
    _coverPath = widget.existing?.coverImagePath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _coverPath = result.files.single.path);
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = '项目名称不能为空');
      return;
    }
    setState(() {
      _nameError = null;
      _isSubmitting = true;
    });

    try {
      final actions = ref.read(projectActionsProvider);
      final desc = _descController.text.trim();

      if (_isEditing) {
        await actions.update(
          id: widget.existing!.id,
          name: name,
          description: desc.isEmpty ? null : desc,
          coverImagePath: _coverPath,
          clearCover: _coverPath == null && widget.existing!.coverImagePath != null,
        );
      } else {
        await actions.create(
          name: name,
          description: desc.isEmpty ? null : desc,
          coverImagePath: _coverPath,
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: Text(_isEditing ? '保存失败' : '创建失败'),
            content: Text('$e'),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Text(_isEditing ? '编辑项目' : '新建项目'),
      constraints: const BoxConstraints(maxWidth: 480),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: '项目名称 *',
            child: TextBox(
              controller: _nameController,
              placeholder: '输入项目名称',
              autofocus: true,
              onChanged: (_) {
                if (_nameError != null) setState(() => _nameError = null);
              },
            ),
          ),
          if (_nameError != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _nameError!,
                style: TextStyle(
                  color: AppColors.error(theme.brightness),
                  fontSize: 12,
                ),
              ),
            ),
          const SizedBox(height: 16),
          InfoLabel(
            label: '项目描述',
            child: TextBox(
              controller: _descController,
              placeholder: '可选：简要描述项目内容',
              maxLines: 4,
            ),
          ),
          const SizedBox(height: 16),
          InfoLabel(
            label: '封面图片',
            child: _buildCoverPicker(theme),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Text(_isEditing ? '保存' : '创建'),
        ),
      ],
    );
  }

  Widget _buildCoverPicker(FluentThemeData theme) {
    if (_coverPath != null && _coverPath!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.file(
              File(_coverPath!),
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: theme.resources.subtleFillColorSecondary,
                child: const Center(child: Text('图片加载失败')),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Button(
                onPressed: _pickCover,
                child: const Text('更换图片'),
              ),
              const SizedBox(width: 8),
              Button(
                onPressed: () => setState(() => _coverPath = null),
                child: const Text('移除'),
              ),
            ],
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: _pickCover,
      child: Container(
        height: 80,
        width: double.infinity,
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.resources.cardStrokeColorDefault,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(4),
          color: theme.resources.subtleFillColorSecondary,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.photo2_add,
                size: 24,
                color: theme.resources.textFillColorSecondary,
              ),
              const SizedBox(height: 4),
              Text(
                '点击选择封面图片',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
