import 'package:fluent_ui/fluent_ui.dart';

import '../../../core/services/ai/ai_models.dart';

class ImagePreviewDialog extends StatelessWidget {
  const ImagePreviewDialog({super.key, required this.image});

  final AiGeneratedImage image;

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
      title: const Text('图片预览'),
      content: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4.0,
        child: Center(child: _buildImage()),
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
    if (image.bytes != null) {
      return Image.memory(
        image.bytes!,
        fit: BoxFit.contain,
      );
    }
    if (image.url != null) {
      return Image.network(
        image.url!,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return const Center(child: ProgressRing());
        },
      );
    }
    return const Icon(FluentIcons.photo2, size: 64);
  }
}
