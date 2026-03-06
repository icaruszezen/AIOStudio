import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class SaveToAssetResult {
  final String projectId;
  final String name;

  const SaveToAssetResult({required this.projectId, required this.name});
}

class SaveToAssetDialog extends ConsumerStatefulWidget {
  const SaveToAssetDialog({
    super.key,
    required this.defaultName,
  });

  final String defaultName;

  @override
  ConsumerState<SaveToAssetDialog> createState() => _SaveToAssetDialogState();
}

class _SaveToAssetDialogState extends ConsumerState<SaveToAssetDialog> {
  late final TextEditingController _nameController;
  String? _selectedProjectId;
  List<Project> _projects = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final dao = ref.read(projectDaoProvider);
    final projects = await dao.getAllProjects();
    if (mounted) {
      setState(() {
        _projects = projects;
        _selectedProjectId = projects.isNotEmpty ? projects.first.id : null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 450),
      title: const Text('保存到资产库'),
      content: _loading
          ? const SizedBox(
              height: 100,
              child: Center(child: ProgressRing()),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('项目', style: theme.typography.bodyStrong),
                const SizedBox(height: 6),
                if (_projects.isEmpty)
                  InfoBar(
                    title: const Text('请先创建一个项目'),
                    severity: InfoBarSeverity.warning,
                  )
                else
                  ComboBox<String>(
                    value: _selectedProjectId,
                    items: _projects
                        .map((p) => ComboBoxItem(
                              value: p.id,
                              child: Text(p.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedProjectId = v),
                    isExpanded: true,
                    placeholder: const Text('选择项目'),
                  ),
                const SizedBox(height: 16),
                Text('资产名称', style: theme.typography.bodyStrong),
                const SizedBox(height: 6),
                TextBox(
                  controller: _nameController,
                  placeholder: '输入资产名称',
                ),
              ],
            ),
      actions: [
        FilledButton(
          onPressed: _canSave
              ? () => Navigator.of(context).pop(SaveToAssetResult(
                    projectId: _selectedProjectId!,
                    name: _nameController.text.trim(),
                  ))
              : null,
          child: const Text('保存'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('取消'),
        ),
      ],
    );
  }

  bool get _canSave =>
      _selectedProjectId != null && _nameController.text.trim().isNotEmpty;
}
