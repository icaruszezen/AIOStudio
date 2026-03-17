import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../prompts/providers/prompts_provider.dart';
import '../../prompts/views/prompt_optimize_dialog.dart';
import '../providers/video_gen_provider.dart';

class VideoGenParamsPanel extends ConsumerStatefulWidget {
  const VideoGenParamsPanel({super.key});

  @override
  ConsumerState<VideoGenParamsPanel> createState() =>
      _VideoGenParamsPanelState();
}

class _VideoGenParamsPanelState extends ConsumerState<VideoGenParamsPanel> {
  final _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending =
          ref.read(pendingPromptContentProvider.notifier).consume();
      if (pending != null && pending.isNotEmpty) {
        _promptController.text = pending;
        ref.read(videoGenProvider.notifier).updatePrompt(pending);
      }
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<VideoGenState>(videoGenProvider, (prev, next) {
      if (prev?.prompt != next.prompt &&
          _promptController.text != next.prompt) {
        _promptController.text = next.prompt;
      }
    });

    final theme = FluentTheme.of(context);
    final genState = ref.watch(videoGenProvider);
    final notifier = ref.read(videoGenProvider.notifier);
    final providers = notifier.getAvailableProviders();

    return Container(
      color: theme.resources.solidBackgroundFillColorBase,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // -- Mode toggle --
                _sectionLabel(theme, '生成模式'),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ToggleButton(
                        checked: genState.mode == VideoGenMode.text2video,
                        onChanged: (_) =>
                            notifier.setMode(VideoGenMode.text2video),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.text_document, size: 14),
                            SizedBox(width: 6),
                            Text('文生视频'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ToggleButton(
                        checked: genState.mode == VideoGenMode.image2video,
                        onChanged: (_) =>
                            notifier.setMode(VideoGenMode.image2video),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(FluentIcons.photo2, size: 14),
                            SizedBox(width: 6),
                            Text('图生视频'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // -- Provider --
                _sectionLabel(theme, '服务商'),
                const SizedBox(height: 6),
                ComboBox<String>(
                  value: genState.selectedProviderId,
                  items: providers
                      .map((s) => ComboBoxItem(
                            value: s.providerId,
                            child: Text(s.providerName),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) notifier.selectProvider(v);
                  },
                  placeholder: const Text('选择服务商'),
                  isExpanded: true,
                ),

                const SizedBox(height: 16),

                // -- Model --
                _sectionLabel(theme, '模型'),
                const SizedBox(height: 6),
                _buildModelSelector(genState, notifier),

                const SizedBox(height: 16),

                // -- Mode-specific inputs --
                if (genState.mode == VideoGenMode.text2video)
                  _buildText2VideoInputs(theme, genState, notifier)
                else
                  _buildImage2VideoInputs(theme, genState, notifier),

                const SizedBox(height: 16),

                // -- Resolution --
                _sectionLabel(theme, '分辨率'),
                const SizedBox(height: 6),
                ComboBox<int>(
                  value: genState.selectedResolutionIndex,
                  items: List.generate(videoResolutions.length, (i) {
                    return ComboBoxItem(
                      value: i,
                      child: Text(videoResolutions[i].label),
                    );
                  }),
                  onChanged: (v) {
                    if (v != null) notifier.selectResolution(v);
                  },
                  isExpanded: true,
                ),

                const SizedBox(height: 16),

                // -- Duration --
                _sectionLabel(theme, '视频时长'),
                const SizedBox(height: 6),
                ComboBox<int>(
                  value: genState.duration,
                  items: videoDurations
                      .map((d) => ComboBoxItem(
                            value: d,
                            child: Text('${d}s'),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) notifier.setDuration(v);
                  },
                  isExpanded: true,
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),

          // -- Generate button --
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.resources.solidBackgroundFillColorBase,
              border: Border(
                top: BorderSide(
                  color: theme.resources.cardStrokeColorDefault,
                ),
              ),
            ),
            child: _buildGenerateButton(theme, genState, notifier),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Text-to-video inputs
  // ---------------------------------------------------------------------------

  Widget _buildText2VideoInputs(
    FluentThemeData theme,
    VideoGenState genState,
    VideoGenNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(theme, '提示词'),
        const SizedBox(height: 6),
        TextBox(
          controller: _promptController,
          maxLines: 8,
          minLines: 4,
          placeholder: '描述你想生成的视频内容...',
          onChanged: notifier.updatePrompt,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              '${_promptController.text.length} 字',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
            const Spacer(),
            _smallButton(
              icon: FluentIcons.library,
              label: '提示词库',
              onPressed: () => _pickFromPromptLibrary(context),
            ),
            const SizedBox(width: 8),
            _smallButton(
              icon: FluentIcons.auto_enhance_on,
              label: 'AI 优化',
              onPressed: _promptController.text.trim().isEmpty
                  ? null
                  : () => _optimizePrompt(context),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Image-to-video inputs
  // ---------------------------------------------------------------------------

  Widget _buildImage2VideoInputs(
    FluentThemeData theme,
    VideoGenState genState,
    VideoGenNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel(theme, '输入图片'),
        const SizedBox(height: 6),
        if (genState.inputImagePath != null) ...[
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: theme.resources.cardStrokeColorDefault,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.file(
                    File(genState.inputImagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Center(
                      child: Icon(FluentIcons.photo2,
                          size: 48,
                          color: theme.resources.textFillColorSecondary),
                    ),
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.overlayDark(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(FluentIcons.cancel,
                          size: 10, color: AppColors.onAccent),
                    ),
                    onPressed: () => notifier.setInputImage(null),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        Row(
          children: [
            Expanded(
              child: Button(
                onPressed: () => _pickLocalImage(notifier),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.upload, size: 14),
                    SizedBox(width: 6),
                    Text('本地上传'),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        _sectionLabel(theme, '运动描述'),
        const SizedBox(height: 6),
        TextBox(
          controller: _promptController,
          maxLines: 4,
          minLines: 2,
          placeholder: '描述图片中物体的运动方式...',
          onChanged: notifier.updatePrompt,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Widget _buildModelSelector(
      VideoGenState genState, VideoGenNotifier notifier) {
    if (genState.selectedProviderId == null) {
      return const ComboBox<String>(
        items: [],
        placeholder: Text('先选择服务商'),
        isExpanded: true,
      );
    }

    final models =
        notifier.getProviderVideoModels(genState.selectedProviderId!);
    return ComboBox<String>(
      value: genState.selectedModel,
      items:
          models.map((m) => ComboBoxItem(value: m, child: Text(m))).toList(),
      onChanged: (v) {
        if (v != null) notifier.selectModel(v);
      },
      placeholder: const Text('选择模型'),
      isExpanded: true,
    );
  }

  Widget _buildGenerateButton(
    FluentThemeData theme,
    VideoGenState genState,
    VideoGenNotifier notifier,
  ) {
    if (genState.isSubmitting) {
      return const Row(
        children: [
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProgressRing(strokeWidth: 3),
                  SizedBox(width: 12),
                  Text('提交中...'),
                ],
              ),
            ),
          ),
        ],
      );
    }

    final bool canGenerate;
    if (genState.mode == VideoGenMode.text2video) {
      canGenerate = genState.prompt.trim().isNotEmpty &&
          genState.selectedProviderId != null &&
          genState.selectedModel != null;
    } else {
      canGenerate = genState.inputImagePath != null &&
          genState.selectedProviderId != null &&
          genState.selectedModel != null;
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: canGenerate ? () => notifier.submitGeneration() : null,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('开始生成', style: TextStyle(fontSize: 15)),
        ),
      ),
    );
  }

  Widget _sectionLabel(FluentThemeData theme, String text) {
    return Text(text, style: theme.typography.bodyStrong);
  }

  Widget _smallButton({
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    return HyperlinkButton(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _pickLocalImage(VideoGenNotifier notifier) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      notifier.setInputImage(result.files.first.path);
    }
  }

  Future<void> _pickFromPromptLibrary(BuildContext context) async {
    final prompts =
        await ref.read(promptDaoProvider).filterByCategory('video_gen');
    if (!context.mounted || prompts.isEmpty) {
      if (context.mounted) {
        await displayInfoBar(context, builder: (ctx, close) {
          return InfoBar(
            title: const Text('暂无视频生成分类的提示词'),
            severity: InfoBarSeverity.info,
            onClose: close,
          );
        });
      }
      return;
    }

    if (!context.mounted) return;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
        title: const Text('选择提示词'),
        content: ListView.builder(
          itemCount: prompts.length,
          itemBuilder: (_, i) {
            final p = prompts[i];
            return ListTile.selectable(
              title: Text(p.title),
              subtitle: Text(
                p.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onPressed: () => Navigator.of(ctx).pop(p.content),
            );
          },
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
        ],
      ),
    );

    if (selected != null && mounted) {
      _promptController.text = selected;
      ref.read(videoGenProvider.notifier).updatePrompt(selected);
    }
  }

  Future<void> _optimizePrompt(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => PromptOptimizeDialog(
        originalContent: _promptController.text,
        category: 'video_gen',
      ),
    );
    if (result != null && mounted) {
      _promptController.text = result;
      ref.read(videoGenProvider.notifier).updatePrompt(result);
    }
  }
}
