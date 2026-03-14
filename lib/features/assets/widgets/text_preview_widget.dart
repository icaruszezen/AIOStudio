import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/theme/design_tokens.dart';

class TextPreviewWidget extends StatefulWidget {
  const TextPreviewWidget({super.key, required this.filePath});

  final String filePath;

  @override
  State<TextPreviewWidget> createState() => _TextPreviewWidgetState();
}

class _TextPreviewWidgetState extends State<TextPreviewWidget> {
  static const _maxLines = 5000;

  String? _content;
  int _totalLines = 0;
  bool _truncated = false;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  @override
  void didUpdateWidget(covariant TextPreviewWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _loadFile();
    }
  }

  Future<void> _loadFile() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final file = File(widget.filePath);
      final lines = await file.readAsLines();
      _totalLines = lines.length;
      _truncated = lines.length > _maxLines;
      _content = (_truncated ? lines.take(_maxLines) : lines).join('\n');
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (_isLoading) {
      return const Center(child: ProgressRing());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.error_badge,
                size: 48, color: theme.resources.textFillColorSecondary),
            const SizedBox(height: 8),
            Text('无法读取文件', style: theme.typography.body),
            const SizedBox(height: 4),
            Text(_error!,
                style: theme.typography.caption
                    ?.copyWith(color: theme.resources.textFillColorSecondary)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: theme.resources.cardBackgroundFillColorDefault,
            border: Border(
              bottom:
                  BorderSide(color: theme.resources.cardStrokeColorDefault),
            ),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.text_document,
                  size: 14, color: theme.resources.textFillColorSecondary),
              const SizedBox(width: 8),
              Text(
                '$_totalLines 行',
                style: theme.typography.caption
                    ?.copyWith(color: theme.resources.textFillColorSecondary),
              ),
              if (_truncated) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '仅显示前 $_maxLines 行',
                    style: theme.typography.caption?.copyWith(
                      color: theme.accentColor,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              _content ?? '',
              style: theme.typography.body?.copyWith(
                fontFamily: DesignTokens.monoFontFamily,
                fontFamilyFallback: DesignTokens.monoFontFallback,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
