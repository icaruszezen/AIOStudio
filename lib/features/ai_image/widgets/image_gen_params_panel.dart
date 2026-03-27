import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../prompts/providers/prompts_provider.dart';
import '../../prompts/views/prompt_optimize_dialog.dart';
import '../providers/image_gen_provider.dart';

class ImageGenParamsPanel extends ConsumerStatefulWidget {
  const ImageGenParamsPanel({super.key});

  @override
  ConsumerState<ImageGenParamsPanel> createState() =>
      _ImageGenParamsPanelState();
}

class _ImageGenParamsPanelState extends ConsumerState<ImageGenParamsPanel> {
  final _promptController = TextEditingController();
  final _negativePromptController = TextEditingController();
  final _widthController = TextEditingController(text: '1024');
  final _heightController = TextEditingController(text: '1024');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = ref.read(pendingPromptContentProvider.notifier).consume();
      if (pending != null && pending.isNotEmpty) {
        _promptController.text = pending;
        ref.read(imageGenProvider.notifier).updatePrompt(pending);
      }
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativePromptController.dispose();
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ImageGenState>(imageGenProvider, (prev, next) {
      if (prev?.prompt != next.prompt &&
          _promptController.text != next.prompt) {
        _promptController.text = next.prompt;
      }
      if (prev?.negativePrompt != next.negativePrompt &&
          _negativePromptController.text != next.negativePrompt) {
        _negativePromptController.text = next.negativePrompt;
      }
      if (prev?.width != next.width &&
          _widthController.text != next.width.toString()) {
        _widthController.text = next.width.toString();
      }
      if (prev?.height != next.height &&
          _heightController.text != next.height.toString()) {
        _heightController.text = next.height.toString();
      }
    });

    final theme = FluentTheme.of(context);
    final genState = ref.watch(imageGenProvider);
    final notifier = ref.read(imageGenProvider.notifier);
    final providers = notifier.getAvailableProviders();
    final capabilities = notifier.getImageGenCapabilities();

    final supportsStyle = capabilities.contains(ImageGenCap.style);
    final supportsQuality = capabilities.contains(ImageGenCap.quality);
    final supportsCfgScale = capabilities.contains(ImageGenCap.cfgScale);
    final supportsSteps = capabilities.contains(ImageGenCap.steps);
    final supportsSeed = capabilities.contains(ImageGenCap.seed);
    final hasAdvancedParams = supportsCfgScale || supportsSteps || supportsSeed;

    return Container(
      color: theme.resources.solidBackgroundFillColorBase,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // -- Provider --
                _sectionLabel(theme, '服务商'),
                const SizedBox(height: 6),
                ComboBox<String>(
                  value: genState.selectedProviderId,
                  items: providers
                      .map(
                        (s) => ComboBoxItem(
                          value: s.providerId,
                          child: Text(s.providerName),
                        ),
                      )
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

                // -- Prompt --
                _sectionLabel(theme, '提示词'),
                const SizedBox(height: 6),
                TextBox(
                  controller: _promptController,
                  maxLines: 8,
                  minLines: 4,
                  placeholder: '描述你想生成的图片...',
                  onChanged: notifier.updatePrompt,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${genState.prompt.length} 字',
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

                const SizedBox(height: 16),

                // -- Negative prompt --
                Expander(
                  header: const Text('负面提示词'),
                  content: TextBox(
                    controller: _negativePromptController,
                    maxLines: 3,
                    minLines: 2,
                    placeholder: '不想出现的内容...',
                    onChanged: notifier.updateNegativePrompt,
                  ),
                ),

                const SizedBox(height: 16),

                // -- Size --
                _sectionLabel(theme, '图片尺寸'),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(sizePresets.length, (i) {
                    final preset = sizePresets[i];
                    final selected = genState.selectedSizePreset == i;
                    return ToggleButton(
                      checked: selected,
                      onChanged: (_) => notifier.selectSizePreset(i),
                      child: Text(
                        preset.label,
                        style: const TextStyle(fontSize: 12),
                      ),
                    );
                  }),
                ),
                if (genState.selectedSizePreset == sizePresets.length - 1) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: NumberBox<int>(
                          value: genState.width,
                          onChanged: (v) {
                            if (v != null) {
                              notifier.setCustomSize(v, genState.height);
                            }
                          },
                          min: 256,
                          max: 2048,
                          mode: SpinButtonPlacementMode.none,
                          placeholder: '宽',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('×'),
                      ),
                      Expanded(
                        child: NumberBox<int>(
                          value: genState.height,
                          onChanged: (v) {
                            if (v != null) {
                              notifier.setCustomSize(genState.width, v);
                            }
                          },
                          min: 256,
                          max: 2048,
                          mode: SpinButtonPlacementMode.none,
                          placeholder: '高',
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),

                // -- Count --
                _sectionLabel(theme, '生成数量'),
                const SizedBox(height: 6),
                NumberBox<int>(
                  value: genState.count,
                  onChanged: (v) {
                    if (v != null) notifier.setCount(v);
                  },
                  min: 1,
                  max: 4,
                  mode: SpinButtonPlacementMode.inline,
                ),

                // -- Style / Quality (capability-driven) --
                if (supportsStyle) ...[
                  const SizedBox(height: 16),
                  _sectionLabel(theme, '风格'),
                  const SizedBox(height: 6),
                  ComboBox<String>(
                    value: genState.style ?? 'vivid',
                    items: const [
                      ComboBoxItem(value: 'vivid', child: Text('vivid (生动)')),
                      ComboBoxItem(
                        value: 'natural',
                        child: Text('natural (自然)'),
                      ),
                    ],
                    onChanged: (v) => notifier.setStyle(v),
                    isExpanded: true,
                  ),
                ],
                if (supportsQuality) ...[
                  const SizedBox(height: 12),
                  _sectionLabel(theme, '质量'),
                  const SizedBox(height: 6),
                  ComboBox<String>(
                    value: genState.quality ?? 'standard',
                    items: const [
                      ComboBoxItem(
                        value: 'standard',
                        child: Text('standard (标准)'),
                      ),
                      ComboBoxItem(value: 'hd', child: Text('hd (高清)')),
                    ],
                    onChanged: (v) => notifier.setQuality(v),
                    isExpanded: true,
                  ),
                ],

                // -- Advanced params (capability-driven) --
                if (hasAdvancedParams) ...[
                  const SizedBox(height: 16),
                  Expander(
                    header: const Text('高级参数'),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (supportsCfgScale) ...[
                          _sectionLabel(
                            theme,
                            'CFG Scale: ${(genState.cfgScale ?? 7.0).toStringAsFixed(1)}',
                          ),
                          Slider(
                            value: genState.cfgScale ?? 7.0,
                            min: 1,
                            max: 30,
                            divisions: 58,
                            onChanged: (v) => notifier.setCfgScale(v),
                            label: (genState.cfgScale ?? 7.0).toStringAsFixed(
                              1,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (supportsSteps) ...[
                          _sectionLabel(
                            theme,
                            'Steps: ${genState.steps ?? 30}',
                          ),
                          Slider(
                            value: (genState.steps ?? 30).toDouble(),
                            min: 10,
                            max: 50,
                            divisions: 40,
                            onChanged: (v) => notifier.setSteps(v.round()),
                            label: '${genState.steps ?? 30}',
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (supportsSeed) ...[
                          _sectionLabel(theme, 'Seed（留空随机）'),
                          const SizedBox(height: 4),
                          NumberBox<int>(
                            value: genState.seed,
                            onChanged: (v) => notifier.setSeed(v),
                            min: 0,
                            max: 4294967295,
                            mode: SpinButtonPlacementMode.none,
                            placeholder: '随机',
                            clearButton: true,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],

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
                top: BorderSide(color: theme.resources.cardStrokeColorDefault),
              ),
            ),
            child: _buildGenerateButton(theme, genState, notifier),
          ),
        ],
      ),
    );
  }

  Widget _buildModelSelector(
    ImageGenState genState,
    ImageGenNotifier notifier,
  ) {
    if (genState.selectedProviderId == null) {
      return const ComboBox<String>(
        items: [],
        placeholder: Text('先选择服务商'),
        isExpanded: true,
      );
    }

    final models = notifier.getProviderImageModels(
      genState.selectedProviderId!,
    );
    return ComboBox<String>(
      value: genState.selectedModel,
      items: models.map((m) => ComboBoxItem(value: m, child: Text(m))).toList(),
      onChanged: (v) {
        if (v != null) notifier.selectModel(v);
      },
      placeholder: const Text('选择模型'),
      isExpanded: true,
    );
  }

  Widget _buildGenerateButton(
    FluentThemeData theme,
    ImageGenState genState,
    ImageGenNotifier notifier,
  ) {
    if (genState.isGenerating) {
      return Row(
        children: [
          const Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProgressRing(strokeWidth: 3),
                  SizedBox(width: 12),
                  Text('生成中...'),
                ],
              ),
            ),
          ),
          Tooltip(
            message: '取消生成',
            child: IconButton(
              icon: const Icon(FluentIcons.cancel, size: 16),
              onPressed: notifier.cancelGeneration,
            ),
          ),
        ],
      );
    }

    final canGenerate =
        genState.prompt.trim().isNotEmpty &&
        genState.selectedProviderId != null &&
        genState.selectedModel != null;

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: canGenerate ? () => notifier.generateImage() : null,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('生成图片', style: TextStyle(fontSize: 15)),
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

  Future<void> _pickFromPromptLibrary(BuildContext context) async {
    final prompts = await ref
        .read(promptDaoProvider)
        .filterByCategory('image_gen');
    if (!context.mounted || prompts.isEmpty) {
      if (context.mounted) {
        await displayInfoBar(
          context,
          builder: (ctx, close) {
            return InfoBar(
              title: const Text('暂无图片生成分类的提示词'),
              severity: InfoBarSeverity.info,
              onClose: close,
            );
          },
        );
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
      ref.read(imageGenProvider.notifier).updatePrompt(selected);
    }
  }

  Future<void> _optimizePrompt(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => PromptOptimizeDialog(
        originalContent: _promptController.text,
        category: 'image_gen',
      ),
    );
    if (result != null && mounted) {
      _promptController.text = result;
      ref.read(imageGenProvider.notifier).updatePrompt(result);
    }
  }
}
