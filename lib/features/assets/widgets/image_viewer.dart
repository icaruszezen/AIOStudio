import 'dart:io';
import 'dart:math' as math;

import 'package:fluent_ui/fluent_ui.dart';

class ImageViewer extends StatefulWidget {
  const ImageViewer({super.key, required this.filePath});

  final String filePath;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  final _controller = TransformationController();
  int _rotationQuarters = 0;
  bool _isFitMode = true;
  bool _isLoading = true;

  double get _currentScale {
    final matrix = _controller.value;
    return math.sqrt(matrix[0] * matrix[0] + matrix[1] * matrix[1]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ImageViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filePath != widget.filePath) {
      _controller.value = Matrix4.identity();
      _rotationQuarters = 0;
      _isFitMode = true;
      _isLoading = true;
    }
  }

  void _zoomIn() {
    final scale = _currentScale;
    final newScale = (scale * 1.25).clamp(0.1, 10.0);
    _applyScale(newScale / scale);
  }

  void _zoomOut() {
    final scale = _currentScale;
    final newScale = (scale / 1.25).clamp(0.1, 10.0);
    _applyScale(newScale / scale);
  }

  void _applyScale(double factor) {
    final scaled = _controller.value.clone()
      ..scaleByDouble(factor, factor, 1.0, 1.0);
    setState(() {
      _controller.value = scaled;
      _isFitMode = false;
    });
  }

  void _resetView() {
    setState(() {
      _controller.value = Matrix4.identity();
      _isFitMode = true;
    });
  }

  void _rotate() {
    setState(() {
      _rotationQuarters = (_rotationQuarters + 1) % 4;
    });
  }

  void _toggleFitOriginal() {
    if (_isLoading) return;
    if (_isFitMode) {
      setState(() {
        _controller.value = Matrix4.identity();
        _isFitMode = false;
      });
    } else {
      _resetView();
    }
  }

  void _onDoubleTap() => _toggleFitOriginal();

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 0.1,
              maxScale: 10.0,
              onInteractionEnd: (_) => setState(() => _isFitMode = false),
              child: Center(
                child: RotatedBox(
                  quarterTurns: _rotationQuarters,
                  child: Image.file(
                    File(widget.filePath),
                    fit: _isFitMode ? BoxFit.contain : null,
                    frameBuilder: (context, child, frame, loaded) {
                      if (!loaded && frame == null) {
                        return const Center(child: ProgressRing());
                      }
                      if (frame != null && _isLoading) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _isLoading = false);
                        });
                      }
                      return child;
                    },
                    errorBuilder: (context, error, stack) => Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(FluentIcons.error_badge,
                              size: 48,
                              color: theme.resources.textFillColorSecondary),
                          const SizedBox(height: 8),
                          Text('无法加载图片',
                              style: theme.typography.body?.copyWith(
                                  color:
                                      theme.resources.textFillColorSecondary)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        _buildToolbar(theme),
      ],
    );
  }

  Widget _buildToolbar(FluentThemeData theme) {
    final scalePercent = (_currentScale * 100).round();

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorDefault,
        border: Border(
          top: BorderSide(color: theme.resources.cardStrokeColorDefault),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(FluentIcons.remove, size: 12),
            onPressed: _zoomOut,
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            child: Text(
              '$scalePercent%',
              textAlign: TextAlign.center,
              style: theme.typography.caption,
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(FluentIcons.add, size: 12),
            onPressed: _zoomIn,
          ),
          const SizedBox(width: 12),
          _divider(theme),
          const SizedBox(width: 12),
          IconButton(
            icon: const Icon(FluentIcons.rotate, size: 14),
            onPressed: _rotate,
          ),
          const SizedBox(width: 12),
          _divider(theme),
          const SizedBox(width: 12),
          Tooltip(
            message: _isFitMode ? '原始大小' : '适应窗口',
            child: IconButton(
              icon: Icon(
                _isFitMode
                    ? FluentIcons.full_screen
                    : FluentIcons.fit_page,
                size: 14,
              ),
              onPressed: _toggleFitOriginal,
            ),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: '重置',
            child: IconButton(
              icon: const Icon(FluentIcons.reset, size: 14),
              onPressed: _resetView,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider(FluentThemeData theme) {
    return Container(
      width: 1,
      height: 16,
      color: theme.resources.cardStrokeColorDefault,
    );
  }
}
