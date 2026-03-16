import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../core/router/app_router.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_indicator.dart';
import '../providers/image_gen_provider.dart';
import 'image_preview_dialog.dart';
import 'save_to_asset_dialog.dart';

Directory? _clipboardTempDir;

class ImageGenResultArea extends ConsumerWidget {
  const ImageGenResultArea({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final genState = ref.watch(imageGenProvider);

    if (genState.isGenerating) {
      return const LoadingIndicator(message: '正在生成图片，请稍候...');
    }

    if (genState.errorMessage != null) {
      return _buildErrorState(context, genState.errorMessage!);
    }

    final result = genState.currentResult;
    if (result == null || result.images.isEmpty) {
      return const EmptyState(
        icon: FluentIcons.photo2,
        title: '开始创作',
        description: '在左侧输入提示词并点击"生成图片"开始创作',
      );
    }

    return _buildResultGrid(context, ref, result, genState);
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.error_badge, size: 48, color: AppColors.error(theme.brightness)),
            const SizedBox(height: 16),
            Text('生成失败', style: theme.typography.subtitle),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.typography.body?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultGrid(
    BuildContext context,
    WidgetRef ref,
    AiImageResponse result,
    ImageGenState genState,
  ) {
    final theme = FluentTheme.of(context);
    final images = result.images;
    final revisedPrompt = images.firstOrNull?.revisedPrompt;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (revisedPrompt != null && revisedPrompt.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.accentColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('修正后的提示词',
                      style: theme.typography.caption?.copyWith(
                        color: theme.accentColor,
                      )),
                  const SizedBox(height: 4),
                  SelectableText(
                    revisedPrompt,
                    style: theme.typography.body,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Expanded(
            child: GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: images.length == 1 ? 1 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: _calcAspectRatio(genState, images.length),
              ),
              itemCount: images.length,
              itemBuilder: (ctx, i) =>
                  _buildImageCard(ctx, ref, images[i], i, genState),
            ),
          ),
        ],
      ),
    );
  }

  double _calcAspectRatio(ImageGenState genState, int count) {
    final imageRatio = genState.width / genState.height;
    final adjustedRatio = count == 1 ? imageRatio * 0.9 : imageRatio * 0.75;
    return adjustedRatio.clamp(0.4, 2.5);
  }

  Widget _buildImageCard(
    BuildContext context,
    WidgetRef ref,
    AiGeneratedImage image,
    int index,
    ImageGenState genState,
  ) {
    final theme = FluentTheme.of(context);
    final imageWidget = _buildImageWidget(image);

    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _showPreview(context, image),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.resources.cardStrokeColorDefault,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: imageWidget,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _actionButton(
              context,
              icon: FluentIcons.save,
              label: '保存到资产',
              onPressed: () => _saveToAsset(context, ref, index, genState),
            ),
            const SizedBox(width: 4),
            _actionButton(
              context,
              icon: FluentIcons.copy,
              label: '复制',
              onPressed: () => _copyToClipboard(context, image),
            ),
            const SizedBox(width: 4),
            _actionButton(
              context,
              icon: FluentIcons.download,
              label: '另存为',
              onPressed: () => _saveAs(context, image),
            ),
            const SizedBox(width: 4),
            _actionButton(
              context,
              icon: FluentIcons.video,
              label: '生成视频',
              onPressed: () => context.go(AppRoutes.aiVideo),
            ),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon, size: 14),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildImageWidget(AiGeneratedImage image) {
    if (image.bytes != null) {
      return Image.memory(
        image.bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(FluentIcons.photo2, size: 48),
        ),
      );
    }
    if (image.url != null) {
      return Image.network(
        image.url!,
        fit: BoxFit.contain,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Center(
            child: ProgressRing(
              value: progress.expectedTotalBytes != null
                  ? progress.cumulativeBytesLoaded /
                      progress.expectedTotalBytes! *
                      100
                  : null,
            ),
          );
        },
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(FluentIcons.photo2, size: 48),
        ),
      );
    }
    return const Center(child: Icon(FluentIcons.photo2, size: 48));
  }

  void _showPreview(BuildContext context, AiGeneratedImage image) {
    showDialog(
      context: context,
      builder: (_) => ImagePreviewDialog(image: image),
    );
  }

  Future<void> _saveToAsset(
    BuildContext context,
    WidgetRef ref,
    int imageIndex,
    ImageGenState genState,
  ) async {
    final result = await showDialog<SaveToAssetResult>(
      context: context,
      builder: (_) => SaveToAssetDialog(
        defaultName: genState.prompt.length > 20
            ? genState.prompt.substring(0, 20)
            : genState.prompt,
      ),
    );

    if (result != null && context.mounted) {
      final asset = await ref.read(imageGenProvider.notifier).saveToAsset(
            imageIndex: imageIndex,
            projectId: result.projectId,
            name: result.name,
            tagIds: result.tagIds,
          );
      if (context.mounted) {
        await displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: Text(asset != null ? '已保存到资产库' : '保存失败'),
            severity:
                asset != null ? InfoBarSeverity.success : InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }

  Future<void> _copyToClipboard(
      BuildContext context, AiGeneratedImage image) async {
    String clipText;
    String infoMsg;

    if (image.url != null) {
      clipText = image.url!;
      infoMsg = '已复制图片 URL';
    } else if (image.bytes != null) {
      try {
        _clipboardTempDir?.deleteSync(recursive: true);
      } catch (_) {}
      _clipboardTempDir = await Directory.systemTemp.createTemp('aio_clipboard_');
      final tmpFile = File(p.join(_clipboardTempDir!.path, 'image.png'));
      await tmpFile.writeAsBytes(image.bytes!);
      clipText = tmpFile.path;
      infoMsg = '已复制图片文件路径';
    } else {
      return;
    }

    await Clipboard.setData(ClipboardData(text: clipText));
    if (context.mounted) {
      await displayInfoBar(context, builder: (ctx, close) {
        return InfoBar(
          title: Text(infoMsg),
          severity: InfoBarSeverity.success,
          onClose: close,
        );
      });
    }
  }

  Future<void> _saveAs(BuildContext context, AiGeneratedImage image) async {
    final outputPath = await FilePicker.platform.saveFile(
      dialogTitle: '另存为',
      fileName: 'generated_image.png',
      type: FileType.image,
    );
    if (outputPath == null) return;

    try {
      final ext = p.extension(outputPath).toLowerCase();
      final savePath = ext.isEmpty ? '$outputPath.png' : outputPath;

      if (image.bytes != null) {
        await File(savePath).writeAsBytes(image.bytes!);
      } else if (image.url != null) {
        final dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 120),
        ));
        try {
          await dio.download(image.url!, savePath);
        } finally {
          dio.close();
        }
      }

      if (context.mounted) {
        await displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: const Text('文件已保存'),
            severity: InfoBarSeverity.success,
            onClose: close,
          );
        });
      }
    } catch (e) {
      if (context.mounted) {
        final userMsg = e is DioException ? '下载图片失败，请检查网络连接' : '保存失败，请重试';
        await displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: Text(userMsg),
            severity: InfoBarSeverity.error,
            onClose: close,
          );
        });
      }
    }
  }
}
