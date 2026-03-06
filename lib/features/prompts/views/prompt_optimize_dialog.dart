import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    _startOptimization();
  }

  Future<void> _startOptimization() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await ref.read(promptActionsProvider).optimizePrompt(
            widget.originalContent,
            widget.category,
          );
      if (mounted) {
        setState(() {
          _optimizedContent = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
      title: const Text('AI 提示词优化'),
      content: _isLoading
          ? _buildLoadingState(theme)
          : _error != null
              ? _buildErrorState(theme)
              : _buildComparisonView(theme),
      actions: [
        if (!_isLoading && _error != null)
          FilledButton(
            onPressed: _startOptimization,
            child: const Text('重试'),
          ),
        if (!_isLoading && _optimizedContent != null)
          FilledButton(
            onPressed: () => Navigator.of(context).pop(_optimizedContent),
            child: const Text('采用优化版本'),
          ),
        Button(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(_optimizedContent != null ? '保留原始' : '取消'),
        ),
      ],
    );
  }

  Widget _buildLoadingState(FluentThemeData theme) {
    return const SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProgressRing(),
            SizedBox(height: 16),
            Text('正在优化提示词...'),
          ],
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
            Icon(FluentIcons.error_badge,
                size: 48, color: Colors.red.normal),
            const SizedBox(height: 16),
            Text(
              '优化失败',
              style: theme.typography.subtitle,
            ),
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
        Text(
          title,
          style: theme.typography.bodyStrong?.copyWith(color: color),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorSecondary,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.resources.cardStrokeColorDefault,
              ),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                content,
                style: theme.typography.body,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
