import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/utils/format_utils.dart';
import '../../projects/providers/projects_provider.dart';
import '../providers/assets_provider.dart';

class AssetImportDialog extends ConsumerStatefulWidget {
  const AssetImportDialog({
    super.key,
    this.initialFiles,
    this.initialProjectId,
  });

  final List<String>? initialFiles;
  final String? initialProjectId;

  static Future<int?> show(
    BuildContext context, {
    List<String>? initialFiles,
    String? initialProjectId,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => AssetImportDialog(
        initialFiles: initialFiles,
        initialProjectId: initialProjectId,
      ),
    );
  }

  @override
  ConsumerState<AssetImportDialog> createState() => _AssetImportDialogState();
}

class _AssetImportDialogState extends ConsumerState<AssetImportDialog> {
  final List<_FileEntry> _files = [];
  String? _selectedProjectId;
  bool _isImporting = false;
  int _importedCount = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
    if (widget.initialFiles != null) {
      _addFiles(widget.initialFiles!);
    }
  }

  Future<void> _addFiles(List<String> paths) async {
    for (final path in paths) {
      await _addFile(path);
    }
    if (mounted) setState(() {});
  }

  Future<void> _addFile(String path) async {
    if (_files.any((f) => f.path == path)) return;
    final file = File(path);
    final stat = await file.stat();
    _files.add(_FileEntry(
      path: path,
      name: file.uri.pathSegments.last,
      size: stat.size,
    ));
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result != null) {
      final paths = result.files
          .where((f) => f.path != null)
          .map((f) => f.path!)
          .toList();
      await _addFiles(paths);
    }
  }

  Future<void> _import() async {
    if (_files.isEmpty) return;
    setState(() {
      _isImporting = true;
      _importedCount = 0;
    });

    try {
      final actions = ref.read(assetActionsProvider);
      for (var i = 0; i < _files.length; i++) {
        await actions.importLocalFiles(
          [_files[i].path],
          projectId: _selectedProjectId,
        );
        if (mounted) {
          setState(() => _importedCount = i + 1);
        }
      }
      if (mounted) {
        Navigator.of(context).pop(_files.length);
      }
    } catch (e) {
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text('导入失败'),
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
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final projectsAsync = ref.watch(activeProjectsProvider);
    final projects = projectsAsync.value ?? <Project>[];

    return ContentDialog(
      title: const Text('导入资产'),
      constraints: const BoxConstraints(maxWidth: 520, maxHeight: 560),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropZone(theme),
          const SizedBox(height: 16),
          InfoLabel(
            label: '目标项目',
            child: ComboBox<String?>(
              value: _selectedProjectId,
              placeholder: const Text('不关联项目'),
              isExpanded: true,
              items: [
                const ComboBoxItem(value: null, child: Text('不关联项目')),
                ...projects.map(
                  (p) => ComboBoxItem(value: p.id, child: Text(p.name)),
                ),
              ],
              onChanged: _isImporting
                  ? null
                  : (v) => setState(() => _selectedProjectId = v),
            ),
          ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '已选文件 (${_files.length})',
              style: theme.typography.bodyStrong,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                itemCount: _files.length,
                itemBuilder: (context, index) {
                  final file = _files[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(
                          _fileIcon(file.name),
                          size: 16,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            file.name,
                            style: theme.typography.body,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatFileSize(file.size),
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                        if (!_isImporting) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              FluentIcons.chrome_close,
                              size: 10,
                              color: theme.resources.textFillColorSecondary,
                            ),
                            onPressed: () =>
                                setState(() => _files.removeAt(index)),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
          if (_isImporting) ...[
            const SizedBox(height: 16),
            ProgressBar(value: (_importedCount / _files.length) * 100),
            const SizedBox(height: 4),
            Text(
              '正在导入... $_importedCount / ${_files.length}',
              style: theme.typography.caption,
            ),
          ],
        ],
      ),
      actions: [
        Button(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isImporting || _files.isEmpty ? null : _import,
          child: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('开始导入'),
        ),
      ],
    );
  }

  Widget _buildDropZone(FluentThemeData theme) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      onDragDone: (details) {
        setState(() => _isDragging = false);
        _addFiles(details.files.map((f) => f.path).toList());
      },
      child: GestureDetector(
        onTap: _isImporting ? null : _pickFiles,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isDragging
                  ? theme.accentColor
                  : theme.resources.cardStrokeColorDefault,
              width: _isDragging ? 2 : 1,
            ),
            color: _isDragging
                ? theme.accentColor.withValues(alpha: 0.06)
                : theme.resources.subtleFillColorSecondary,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isDragging ? FluentIcons.cloud_upload : FluentIcons.add,
                  size: 28,
                  color: _isDragging
                      ? theme.accentColor
                      : theme.resources.textFillColorSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  _isDragging ? '释放文件以添加' : '拖拽文件到此处，或点击选择文件',
                  style: theme.typography.body?.copyWith(
                    color: _isDragging
                        ? theme.accentColor
                        : theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static IconData _fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' || 'bmp' || 'svg' =>
        FluentIcons.photo2,
      'mp4' || 'avi' || 'mov' || 'mkv' || 'webm' => FluentIcons.video,
      'mp3' || 'wav' || 'flac' || 'aac' || 'ogg' =>
        FluentIcons.music_in_collection,
      'txt' || 'md' || 'json' || 'xml' || 'csv' =>
        FluentIcons.text_document,
      _ => FluentIcons.document,
    };
  }

}

class _FileEntry {
  const _FileEntry({
    required this.path,
    required this.name,
    required this.size,
  });

  final String path;
  final String name;
  final int size;
}
