import 'dart:async';
import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart'
    show activeProjectsProvider;
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/error_utils.dart';
import '../providers/prompts_provider.dart';
import 'prompt_optimize_dialog.dart';

class PromptEditorPanel extends ConsumerStatefulWidget {
  const PromptEditorPanel({super.key, required this.promptId});

  final String promptId;

  @override
  ConsumerState<PromptEditorPanel> createState() => _PromptEditorPanelState();
}

class _PromptEditorPanelState extends ConsumerState<PromptEditorPanel> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String? _category;
  String? _projectId;
  bool _isFavorite = false;

  Timer? _autoSaveTimer;
  bool _isDirty = false;
  bool _isInitialized = false;
  String? _loadedPromptId;

  final _variableRegex = RegExp(r'\{\{(\w+)\}\}');
  List<_PromptVariable> _variables = [];
  ProviderSubscription<AsyncValue<Prompt?>>? _promptSub;

  @override
  void initState() {
    super.initState();
    _promptSub = ref.listenManual(
      promptDetailProvider(widget.promptId),
      (_, next) {
        next.whenData((prompt) {
          if (prompt != null) _loadPrompt(prompt);
        });
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _promptSub?.close();
    _autoSaveTimer?.cancel();
    if (_isDirty) _saveSync();
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _saveSync() {
    _isDirty = false;
    final variablesJson = _variables.isEmpty
        ? null
        : jsonEncode(_variables.map((v) => v.toJson()).toList());
    ref.read(promptActionsProvider).updatePrompt(
          id: widget.promptId,
          title: _titleController.text,
          content: _contentController.text,
          category: _category,
          variables: variablesJson,
          projectId: _projectId,
        );
  }

  void _loadPrompt(Prompt prompt) {
    if (_loadedPromptId == prompt.id && _isInitialized) return;

    _autoSaveTimer?.cancel();
    _isDirty = false;
    _loadedPromptId = prompt.id;
    _isInitialized = true;

    _titleController.text = prompt.title;
    _contentController.text = prompt.content;
    setState(() {
      _category = prompt.category;
      _projectId = prompt.projectId;
      _isFavorite = prompt.isFavorite;
    });

    _parseVariables(prompt.content, prompt.variables);
  }

  void _parseVariables(String content, String? savedVariablesJson) {
    final matches = _variableRegex.allMatches(content);
    final names = matches.map((m) => m.group(1)!).toSet();

    final Map<String, _PromptVariable> savedMap = {};
    if (savedVariablesJson != null && savedVariablesJson.isNotEmpty) {
      try {
        final list = jsonDecode(savedVariablesJson) as List;
        for (final item in list) {
          final v = _PromptVariable.fromJson(item as Map<String, dynamic>);
          savedMap[v.name] = v;
        }
      } catch (_) {}
    }

    _variables = names.map((name) {
      return savedMap[name] ?? _PromptVariable(name: name);
    }).toList();
  }

  void _onContentChanged() {
    final content = _contentController.text;
    final matches = _variableRegex.allMatches(content);
    final names = matches.map((m) => m.group(1)!).toSet();

    final existingMap = {for (final v in _variables) v.name: v};
    final updated = names.map((name) {
      return existingMap[name] ?? _PromptVariable(name: name);
    }).toList();

    setState(() {
      if (_variablesChanged(updated)) {
        _variables = updated;
      }
    });

    _scheduleSave();
  }

  bool _variablesChanged(List<_PromptVariable> newVars) {
    if (newVars.length != _variables.length) return true;
    final oldNames = _variables.map((v) => v.name).toSet();
    final newNames = newVars.map((v) => v.name).toSet();
    return !oldNames.containsAll(newNames) || !newNames.containsAll(oldNames);
  }

  void _scheduleSave() {
    _isDirty = true;
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 1000), _save);
  }

  Future<void> _save() async {
    if (!_isDirty || !mounted) return;
    _isDirty = false;

    final variablesJson =
        _variables.isEmpty ? null : jsonEncode(_variables.map((v) => v.toJson()).toList());

    await ref.read(promptActionsProvider).updatePrompt(
          id: widget.promptId,
          title: _titleController.text,
          content: _contentController.text,
          category: _category,
          variables: variablesJson,
          projectId: _projectId,
        );
  }

  Future<void> _toggleFavorite() async {
    await ref.read(promptActionsProvider).toggleFavorite(widget.promptId);
    setState(() => _isFavorite = !_isFavorite);
  }

  Future<void> _copyToClipboard() async {
    String result = _contentController.text;
    for (final v in _variables) {
      if (v.defaultValue != null && v.defaultValue!.isNotEmpty) {
        result = result.replaceAll('{{${v.name}}}', v.defaultValue!);
      }
    }
    await Clipboard.setData(ClipboardData(text: result));
    if (mounted) {
      await displayInfoBar(context, builder: (_, close) {
        return InfoBar(
          title: const Text('已复制到剪贴板'),
          severity: InfoBarSeverity.success,
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
        );
      });
    }
  }

  Future<void> _showOptimizeDialog() async {
    await _save();
    if (!mounted) return;

    final optimized = await showDialog<String>(
      context: context,
      builder: (_) => PromptOptimizeDialog(
        originalContent: _contentController.text,
        category: _category,
      ),
    );

    if (optimized != null && mounted) {
      setState(() {
        _contentController.text = optimized;
        _onContentChanged();
      });
    }
  }

  Future<void> _navigateAndUse(String route) async {
    await _save();
    await ref.read(promptActionsProvider).incrementUseCount(widget.promptId);
    if (!mounted) return;

    String content = _contentController.text;
    for (final v in _variables) {
      if (v.defaultValue != null && v.defaultValue!.isNotEmpty) {
        content = content.replaceAll('{{${v.name}}}', v.defaultValue!);
      }
    }
    ref.read(pendingPromptContentProvider.notifier).set(content);
    context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final promptAsync = ref.watch(promptDetailProvider(widget.promptId));

    return promptAsync.when(
      loading: () => const Center(child: ProgressRing()),
      error: (e, _) => Center(child: Text(formatUserError(e))),
      data: (prompt) {
        if (prompt == null) {
          return const Center(child: Text('提示词不存在'));
        }
        return _buildEditor(theme);
      },
    );
  }

  Widget _buildEditor(FluentThemeData theme) {
    final projectsAsync = ref.watch(activeProjectsProvider);

    return Column(
      children: [
        _buildToolbar(theme),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleField(theme),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _buildCategoryField(theme)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildProjectField(theme, projectsAsync),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildContentField(theme),
                const SizedBox(height: 8),
                _buildCharCount(theme),
                if (_variables.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _buildVariablesPanel(theme),
                ],
                const SizedBox(height: 20),
                _buildHighlightedPreview(theme),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.resources.cardStrokeColorDefault,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            '提示词编辑',
            style: theme.typography.subtitle,
          ),
          const Spacer(),
          Tooltip(
            message: _isFavorite ? '取消收藏' : '收藏',
            child: IconButton(
              icon: Icon(
                _isFavorite ? FluentIcons.heart_fill : FluentIcons.heart,
                color: _isFavorite ? AppColors.favorite : null,
                size: 16,
              ),
              onPressed: _toggleFavorite,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: '复制内容',
            child: IconButton(
              icon: const Icon(FluentIcons.copy, size: 16),
              onPressed: _copyToClipboard,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: 'AI 优化',
            child: IconButton(
              icon: const Icon(FluentIcons.auto_enhance_on, size: 16),
              onPressed: _showOptimizeDialog,
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: '在 AI 对话中使用',
            child: IconButton(
              icon: const Icon(FluentIcons.chat, size: 16),
              onPressed: () => _navigateAndUse(AppRoutes.aiChat),
            ),
          ),
          const SizedBox(width: 4),
          Tooltip(
            message: '用于图片生成',
            child: IconButton(
              icon: const Icon(FluentIcons.photo2, size: 16),
              onPressed: () => _navigateAndUse(AppRoutes.aiImage),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () async {
              await _save();
              if (!mounted) return;
              displayInfoBar(context, builder: (_, close) {
                return InfoBar(
                  title: const Text('已保存'),
                  severity: InfoBarSeverity.success,
                  action: IconButton(
                    icon: const Icon(FluentIcons.clear),
                    onPressed: close,
                  ),
                );
              });
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField(FluentThemeData theme) {
    return InfoLabel(
      label: '标题',
      child: TextBox(
        controller: _titleController,
        placeholder: '输入提示词标题',
        onChanged: (_) => _scheduleSave(),
      ),
    );
  }

  Widget _buildCategoryField(FluentThemeData theme) {
    return InfoLabel(
      label: '分类',
      child: ComboBox<String>(
        value: _category,
        placeholder: const Text('选择分类'),
        isExpanded: true,
        items: promptCategories
            .map((c) => ComboBoxItem(value: c.value, child: Text(c.label)))
            .toList(),
        onChanged: (v) {
          setState(() => _category = v);
          _scheduleSave();
        },
      ),
    );
  }

  Widget _buildProjectField(
      FluentThemeData theme, AsyncValue<List<Project>> projectsAsync) {
    return InfoLabel(
      label: '所属项目（可选）',
      child: projectsAsync.when(
        loading: () => const ComboBox<String>(
          placeholder: Text('加载中...'),
          items: [],
          isExpanded: true,
          onChanged: null,
        ),
        error: (_, __) => const ComboBox<String>(
          placeholder: Text('加载失败'),
          items: [],
          isExpanded: true,
          onChanged: null,
        ),
        data: (projects) => ComboBox<String>(
          value: _projectId,
          placeholder: const Text('无'),
          isExpanded: true,
          items: [
            const ComboBoxItem(value: null, child: Text('无')),
            ...projects.map(
              (p) => ComboBoxItem(value: p.id, child: Text(p.name)),
            ),
          ],
          onChanged: (v) {
            setState(() => _projectId = v);
            _scheduleSave();
          },
        ),
      ),
    );
  }

  Widget _buildContentField(FluentThemeData theme) {
    return InfoLabel(
      label: '提示词内容',
      child: TextBox(
        controller: _contentController,
        placeholder: '输入提示词内容...\n\n使用 {{variable_name}} 语法插入变量',
        maxLines: null,
        minLines: 10,
        onChanged: (_) => _onContentChanged(),
      ),
    );
  }

  Widget _buildCharCount(FluentThemeData theme) {
    final text = _contentController.text;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          '${text.length} 字符',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorTertiary,
          ),
        ),
        if (_variables.isNotEmpty) ...[
          const SizedBox(width: 12),
          Text(
            '${_variables.length} 个变量',
            style: theme.typography.caption?.copyWith(
              color: theme.accentColor,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHighlightedPreview(FluentThemeData theme) {
    final content = _contentController.text;
    if (content.isEmpty) return const SizedBox.shrink();

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in _variableRegex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
          text: content.substring(lastEnd, match.start),
          style: theme.typography.body,
        ));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: theme.typography.body?.copyWith(
          color: theme.accentColor,
          fontWeight: FontWeight.w600,
          backgroundColor: theme.accentColor.withValues(alpha: 0.08),
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastEnd),
        style: theme.typography.body,
      ));
    }

    if (spans.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('预览', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.resources.subtleFillColorSecondary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.resources.cardStrokeColorDefault,
            ),
          ),
          child: RichText(text: TextSpan(children: spans)),
        ),
      ],
    );
  }

  Widget _buildVariablesPanel(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('变量', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.resources.subtleFillColorSecondary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: theme.resources.cardStrokeColorDefault,
            ),
          ),
          child: Column(
            children: [
              for (int i = 0; i < _variables.length; i++) ...[
                if (i > 0)
                  Divider(
                    style: DividerThemeData(
                      horizontalMargin:
                          const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.resources.cardStrokeColorDefault,
                      ),
                    ),
                  ),
                _buildVariableRow(theme, i),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVariableRow(FluentThemeData theme, int index) {
    final variable = _variables[index];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              '{{${variable.name}}}',
              style: theme.typography.caption?.copyWith(
                color: theme.accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _VariableTextBox(
              placeholder: '默认值',
              value: variable.defaultValue ?? '',
              onChanged: (v) {
                _variables[index] = variable.copyWith(defaultValue: v);
                _scheduleSave();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _VariableTextBox(
              placeholder: '描述',
              value: variable.description ?? '',
              onChanged: (v) {
                _variables[index] = variable.copyWith(description: v);
                _scheduleSave();
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PromptVariable {
  final String name;
  final String? defaultValue;
  final String? description;

  const _PromptVariable({
    required this.name,
    this.defaultValue,
    this.description,
  });

  _PromptVariable copyWith({String? defaultValue, String? description}) {
    return _PromptVariable(
      name: name,
      defaultValue: defaultValue ?? this.defaultValue,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (defaultValue != null) 'default': defaultValue,
        if (description != null) 'description': description,
      };

  factory _PromptVariable.fromJson(Map<String, dynamic> json) {
    return _PromptVariable(
      name: json['name'] as String,
      defaultValue: json['default'] as String?,
      description: json['description'] as String?,
    );
  }
}

/// A TextBox that initializes its controller with a value but still supports
/// onChanged callbacks. Needed because fluent_ui TextBox lacks initialValue.
class _VariableTextBox extends StatefulWidget {
  const _VariableTextBox({
    required this.placeholder,
    required this.value,
    required this.onChanged,
  });

  final String placeholder;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_VariableTextBox> createState() => _VariableTextBoxState();
}

class _VariableTextBoxState extends State<_VariableTextBox> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _VariableTextBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value &&
        _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextBox(
      controller: _controller,
      placeholder: widget.placeholder,
      onChanged: widget.onChanged,
    );
  }
}
