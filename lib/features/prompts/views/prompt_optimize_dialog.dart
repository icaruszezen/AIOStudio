import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ai_providers.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/error_utils.dart';
import '../providers/prompts_provider.dart';

class PromptOptimizeDialog extends ConsumerStatefulWidget {
  const PromptOptimizeDialog({
    super.key,
    required this.originalContent,
    this.category,
  });

  final String originalContent;
  final String? category;

  @override
  ConsumerState<PromptOptimizeDialog> createState() =>
      _PromptOptimizeDialogState();
}

class _PromptOptimizeDialogState extends ConsumerState<PromptOptimizeDialog> {
  bool _isLoading = false;
  String? _optimizedContent;
  String? _error;
  String? _selectedModelId;
  bool _cancelled = false;

  @override
  void dispose() {
    _cancelled = true;
    super.dispose();
  }

  Future<void> _startOptimization() async {
    if (_selectedModelId == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _optimizedContent = null;
    });

    try {
      final result = await ref
          .read(promptActionsProvider)
          .optimizePrompt(
            widget.originalContent,
            widget.category,
            modelId: _selectedModelId,
          );
      if (mounted && !_cancelled) {
        setState(() {
          _optimizedContent = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && !_cancelled) {
        setState(() {
          _error = formatUserError(e);
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final modelsAsync = ref.watch(availableModelsProvider('chat'));

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
      title: const Text('AI 提示词优化'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildModelSelector(theme, modelsAsync),
          const SizedBox(height: 12),
          Flexible(
            child: _isLoading
                ? _buildLoadingState(theme)
                : _error != null
                ? _buildErrorState(theme)
                : _optimizedContent != null
                ? _buildComparisonView(theme)
                : _buildInitialState(theme),
          ),
        ],
      ),
      actions: [
        if (!_isLoading && _optimizedContent == null && _error == null)
          FilledButton(
            onPressed: _selectedModelId != null ? _startOptimization : null,
            child: const Text('开始优化'),
          ),
        if (!_isLoading && _error != null)
          FilledButton(onPressed: _startOptimization, child: const Text('重试')),
        if (!_isLoading && _optimizedContent != null) ...[
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_optimizedContent),
            child: const Text('采用优化版本'),
          ),
          Button(onPressed: _startOptimization, child: const Text('重新优化')),
        ],
        Button(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(_optimizedContent != null ? '保留原始' : '取消'),
        ),
      ],
    );
  }

  Widget _buildModelSelector(
    FluentThemeData theme,
    AsyncValue<List<AiModelInfo>> modelsAsync,
  ) {
    return modelsAsync.when(
      loading: () => InfoLabel(
        label: '选择模型',
        child: const SizedBox(height: 32, child: ProgressBar()),
      ),
      error: (e, _) => InfoLabel(
        label: '选择模型',
        child: Text(
          formatUserError(e),
          style: TextStyle(color: AppColors.error(theme.brightness)),
        ),
      ),
      data: (models) {
        if (models.isNotEmpty && _selectedModelId == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _selectedModelId == null) {
              setState(() => _selectedModelId = models.first.id);
            }
          });
        }
        return InfoLabel(
          label: '选择模型',
          child: ComboBox<String>(
            value: _selectedModelId,
            placeholder: const Text('选择一个模型'),
            isExpanded: true,
            items: models
                .map((m) => ComboBoxItem(value: m.id, child: Text(m.id)))
                .toList(),
            onChanged: _isLoading
                ? null
                : (v) => setState(() => _selectedModelId = v),
          ),
        );
      },
    );
  }

  Widget _buildInitialState(FluentThemeData theme) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          '选择模型后点击「开始优化」',
          style: theme.typography.body?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(FluentThemeData theme) {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [ProgressRing(), SizedBox(height: 16), Text('正在优化提示词...')],
        ),
      ),
    );
  }

  Widget _buildErrorState(FluentThemeData theme) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.error_badge,
              size: 48,
              color: AppColors.error(theme.brightness),
            ),
            const SizedBox(height: 16),
            Text('优化失败', style: theme.typography.subtitle),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonView(FluentThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildVersionColumn(
            theme,
            title: '原始版本',
            content: widget.originalContent,
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        Container(
          width: 1,
          margin: const EdgeInsets.symmetric(horizontal: 12),
          color: theme.resources.cardStrokeColorDefault,
        ),
        Expanded(
          child: _buildVersionColumn(
            theme,
            title: '优化版本',
            content: _optimizedContent!,
            color: theme.accentColor,
          ),
        ),
      ],
    );
  }

  Widget _buildVersionColumn(
    FluentThemeData theme, {
    required String title,
    required String content,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: theme.typography.bodyStrong?.copyWith(color: color)),
        const SizedBox(height: 8),
        Flexible(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorSecondary,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.resources.cardStrokeColorDefault),
            ),
            child: SingleChildScrollView(
              child: SelectableText(content, style: theme.typography.body),
            ),
          ),
        ),
      ],
    );
  }
}
