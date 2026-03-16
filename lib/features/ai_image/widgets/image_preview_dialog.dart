import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/services/ai/ai_models.dart';

class ImagePreviewDialog extends StatefulWidget {
  const ImagePreviewDialog({super.key, required this.image});

  final AiGeneratedImage image;

  @override
  State<ImagePreviewDialog> createState() => _ImagePreviewDialogState();
}

class _ImagePreviewDialogState extends State<ImagePreviewDialog> {
  final _transformController = TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.sizeOf(context);
    final maxW = (screenSize.width * 0.85).clamp(400.0, 1200.0);
    final maxH = (screenSize.height * 0.85).clamp(300.0, 900.0);

    return ContentDialog(
      constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
      title: Row(
        children: [
          const Text('图片预览'),
          const Spacer(),
          Tooltip(
            message: '重置缩放',
            child: IconButton(
              icon: const Icon(FluentIcons.picture_center, size: 16),
              onPressed: _resetZoom,
            ),
          ),
        ],
      ),
      content: GestureDetector(
        onDoubleTap: _resetZoom,
        child: InteractiveViewer(
          transformationController: _transformController,
          minScale: 0.5,
          maxScale: 5.0,
          child: Center(child: _buildImage()),
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _buildImage() {
    if (widget.image.bytes != null) {
      return Image.memory(
        widget.image.bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, error, __) => _buildErrorPlaceholder(error),
      );
    }
    if (widget.image.url != null) {
      return Image.network(
        widget.image.url!,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: ProgressRing());
        },
        errorBuilder: (_, error, __) => _buildErrorPlaceholder(error),
      );
    }
    return const Icon(FluentIcons.photo2, size: 64);
  }

  Widget _buildErrorPlaceholder(Object error) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(FluentIcons.photo2, size: 64),
        const SizedBox(height: 12),
        Text(
          '图片加载失败',
          style: FluentTheme.of(context).typography.body,
        ),
      ],
    );
  }
}
