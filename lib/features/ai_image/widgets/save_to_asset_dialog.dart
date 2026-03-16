import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';

class SaveToAssetResult {
  final String projectId;
  final String name;
  final List<String> tagIds;

  const SaveToAssetResult({
    required this.projectId,
    required this.name,
    this.tagIds = const [],
  });
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
  List<Tag> _allTags = [];
  final Set<String> _selectedTagIds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final projectDao = ref.read(projectDaoProvider);
      final tagDao = ref.read(tagDaoProvider);
      final projects = await projectDao.getAllProjects();
      final tags = await tagDao.getAllTags();
      if (mounted) {
        setState(() {
          _projects = projects;
          _allTags = tags;
          _selectedProjectId = projects.isNotEmpty ? projects.first.id : null;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        await displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: const Text('加载数据失败，请关闭后重试'),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
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
                  const InfoBar(
                    title: Text('请先创建一个项目'),
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
                if (_allTags.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('标签', style: theme.typography.bodyStrong),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _allTags.map((tag) {
                      final selected = _selectedTagIds.contains(tag.id);
                      return ToggleButton(
                        checked: selected,
                        onChanged: (_) {
                          setState(() {
                            if (selected) {
                              _selectedTagIds.remove(tag.id);
                            } else {
                              _selectedTagIds.add(tag.id);
                            }
                          });
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tag.color != null) ...[
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: Color(tag.color!),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(tag.name,
                                style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
      actions: [
        FilledButton(
          onPressed: _canSave
              ? () => Navigator.of(context).pop(SaveToAssetResult(
                    projectId: _selectedProjectId!,
                    name: _nameController.text.trim(),
                    tagIds: _selectedTagIds.toList(),
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
