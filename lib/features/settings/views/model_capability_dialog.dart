import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/ai_providers.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/model_capability_presets.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/settings_provider.dart';

class ModelCapabilityDialog extends ConsumerStatefulWidget {
  const ModelCapabilityDialog({super.key, required this.model});

  final AiModelInfo model;

  static Future<AiModelInfo?> show(
    BuildContext context, {
    required AiModelInfo model,
  }) {
    return showDialog<AiModelInfo>(
      context: context,
      builder: (_) => ModelCapabilityDialog(model: model),
    );
  }

  @override
  ConsumerState<ModelCapabilityDialog> createState() =>
      _ModelCapabilityDialogState();
}

class _ModelCapabilityDialogState extends ConsumerState<ModelCapabilityDialog> {
  late String _mode;
  late int? _contextWindow;
  late int? _maxOutputTokens;
  late Set<String> _inputModalities;
  late Set<String> _outputModalities;
  late bool _supportsVision;
  late bool _supportsFunctionCalling;
  late bool _supportsReasoning;
  late bool _supportsResponseSchema;
  late bool _supportsWebSearch;
  late bool _supportsAudioInput;
  late bool _supportsAudioOutput;
  late bool _supportsParallelFunctionCalling;
  late bool _supportsPromptCaching;
  late bool _supportsSystemMessages;

  late final TextEditingController _contextCtrl;
  late final TextEditingController _maxOutputCtrl;
  late final TextEditingController _searchCtrl;

  List<AiModelInfo> _searchResults = [];
  bool _isUpdatingRegistry = false;
  String? _registryStatus;
  String _lastSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadFrom(widget.model);
    _contextCtrl = TextEditingController(
      text: widget.model.contextWindow?.toString() ?? '',
    );
    _maxOutputCtrl = TextEditingController(
      text: widget.model.maxOutputTokens?.toString() ?? '',
    );
    _searchCtrl = TextEditingController();
    _ensureRegistryLoaded();
  }

  Future<void> _ensureRegistryLoaded() async {
    final registry = ref.read(modelCapabilityRegistryProvider);
    if (!registry.isLoaded) {
      await registry.load();
      if (mounted) setState(() {});
    }
  }

  Future<void> _updateRegistryFromRemote() async {
    if (_isUpdatingRegistry) return;
    setState(() {
      _isUpdatingRegistry = true;
      _registryStatus = null;
    });
    try {
      final registry = ref.read(modelCapabilityRegistryProvider);
      final mirror = ref.read(githubMirrorProvider);
      final ok = await registry.updateFromRemote(githubMirror: mirror);
      if (mounted) {
        setState(() {
          _isUpdatingRegistry = false;
          if (ok) {
            _registryStatus = '已更新，可搜索 4000+ 模型';
          } else {
            _registryStatus = registry.lastError ?? '更新失败，使用本地数据';
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingRegistry = false;
          _registryStatus = '更新失败: $e';
        });
      }
    }
  }

  void _loadFrom(AiModelInfo m) {
    _mode = m.mode;
    _contextWindow = m.contextWindow;
    _maxOutputTokens = m.maxOutputTokens;
    _inputModalities = Set.of(m.inputModalities);
    _outputModalities = Set.of(m.outputModalities);
    _supportsVision = m.supportsVision;
    _supportsFunctionCalling = m.supportsFunctionCalling;
    _supportsReasoning = m.supportsReasoning;
    _supportsResponseSchema = m.supportsResponseSchema;
    _supportsWebSearch = m.supportsWebSearch;
    _supportsAudioInput = m.supportsAudioInput;
    _supportsAudioOutput = m.supportsAudioOutput;
    _supportsParallelFunctionCalling = m.supportsParallelFunctionCalling;
    _supportsPromptCaching = m.supportsPromptCaching;
    _supportsSystemMessages = m.supportsSystemMessages;
  }

  void _applyPreset(ModelCapabilityPreset preset) {
    final m = preset.apply(widget.model.id);
    setState(() {
      _loadFrom(m);
      _contextCtrl.text = m.contextWindow?.toString() ?? '';
      _maxOutputCtrl.text = m.maxOutputTokens?.toString() ?? '';
    });
  }

  void _applyFromRegistry(AiModelInfo m) {
    setState(() {
      _loadFrom(m);
      _contextCtrl.text = m.contextWindow?.toString() ?? '';
      _maxOutputCtrl.text = m.maxOutputTokens?.toString() ?? '';
      _searchCtrl.clear();
      _searchResults = [];
    });
  }

  void _resetToAutoDetect() {
    final registry = ref.read(modelCapabilityRegistryProvider);
    final auto = registry.lookup(widget.model.id);
    if (auto != null) {
      _applyFromRegistry(auto);
    } else {
      _applyFromRegistry(AiModelInfo(id: widget.model.id));
    }
  }

  AiModelInfo _buildResult() {
    return widget.model.copyWith(
      mode: _mode,
      contextWindow: _contextWindow,
      maxOutputTokens: _maxOutputTokens,
      inputModalities: _inputModalities.toList(),
      outputModalities: _outputModalities.toList(),
      supportsVision: _supportsVision,
      supportsFunctionCalling: _supportsFunctionCalling,
      supportsReasoning: _supportsReasoning,
      supportsResponseSchema: _supportsResponseSchema,
      supportsWebSearch: _supportsWebSearch,
      supportsAudioInput: _supportsAudioInput,
      supportsAudioOutput: _supportsAudioOutput,
      supportsParallelFunctionCalling: _supportsParallelFunctionCalling,
      supportsPromptCaching: _supportsPromptCaching,
      supportsSystemMessages: _supportsSystemMessages,
    );
  }

  @override
  void dispose() {
    _contextCtrl.dispose();
    _maxOutputCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Text('编辑模型能力 - ${widget.model.id}'),
      constraints: const BoxConstraints(maxWidth: 620, maxHeight: 640),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPresetSection(theme),
            const SizedBox(height: 16),
            _buildBasicParams(theme),
            const SizedBox(height: 16),
            _buildModalitySection(theme),
            const SizedBox(height: 16),
            _buildCapabilityToggles(theme),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        Button(
          onPressed: _resetToAutoDetect,
          child: const Text('重置为自动检测'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_buildResult()),
          child: const Text('保存'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Preset section
  // ---------------------------------------------------------------------------

  Widget _buildPresetSection(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '从已知模型应用能力',
                style: theme.typography.bodyStrong,
              ),
            ),
            if (_isUpdatingRegistry)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: SizedBox(
                  width: 12,
                  height: 12,
                  child: ProgressRing(strokeWidth: 2),
                ),
              ),
            if (_registryStatus != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _registryStatus!,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ),
            HyperlinkButton(
              onPressed: _isUpdatingRegistry ? null : _updateRegistryFromRemote,
              child: const Text('更新模型库'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        AutoSuggestBox<AiModelInfo>(
          controller: _searchCtrl,
          placeholder: '搜索模型库...',
          items: _searchResults
              .map((m) => AutoSuggestBoxItem<AiModelInfo>(
                    value: m,
                    label: m.id,
                    child: _SearchResultTile(model: m, theme: theme),
                  ))
              .toList(),
          onChanged: (text, reason) {
            if (reason == TextChangedReason.userInput && text.isNotEmpty) {
              final registry = ref.read(modelCapabilityRegistryProvider);
              if (!registry.isLoaded) {
                registry.load().then((_) {
                  if (!mounted) return;
                  setState(() {
                    _lastSearchQuery = text;
                    _searchResults =
                        registry.searchModels(text, limit: 12);
                  });
                });
              } else {
                setState(() {
                  _lastSearchQuery = text;
                  _searchResults =
                      registry.searchModels(text, limit: 12);
                });
              }
            } else if (text.isEmpty) {
              setState(() {
                _lastSearchQuery = '';
                _searchResults = [];
              });
            }
          },
          onSelected: (item) {
            if (item.value != null) _applyFromRegistry(item.value!);
          },
        ),
        if (_lastSearchQuery.isNotEmpty && _searchResults.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '未找到 "$_lastSearchQuery"，可点击"更新模型库"获取更多模型，或使用下方快捷模板/手动设置',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text('快捷类别模板', style: theme.typography.bodyStrong),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: ModelCapabilityPresets.all
              .map((p) => _PresetChip(
                    preset: p,
                    theme: theme,
                    onTap: () => _applyPreset(p),
                  ))
              .toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Basic params
  // ---------------------------------------------------------------------------

  Widget _buildBasicParams(FluentThemeData theme) {
    const modes = [
      ('chat', '对话'),
      ('image_generation', '图片生成'),
      ('embedding', '嵌入'),
      ('audio_transcription', '语音转录'),
      ('audio_speech', '语音合成'),
      ('completion', '补全'),
      ('moderation', '审核'),
      ('rerank', '重排序'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('基础参数', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        InfoLabel(
          label: '模式',
          child: ComboBox<String>(
            value: modes.any((e) => e.$1 == _mode) ? _mode : 'chat',
            items: modes
                .map((e) => ComboBoxItem(value: e.$1, child: Text(e.$2)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _mode = v);
            },
            isExpanded: true,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: InfoLabel(
                label: '上下文窗口 (Token)',
                child: TextBox(
                  controller: _contextCtrl,
                  placeholder: '如 128000',
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    _contextWindow = int.tryParse(v);
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InfoLabel(
                label: '最大输出 Token',
                child: TextBox(
                  controller: _maxOutputCtrl,
                  placeholder: '如 16384',
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    _maxOutputTokens = int.tryParse(v);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Modalities
  // ---------------------------------------------------------------------------

  Widget _buildModalitySection(FluentThemeData theme) {
    const allModalities = ['text', 'image', 'audio', 'video'];
    const labels = {
      'text': '文本',
      'image': '图像',
      'audio': '音频',
      'video': '视频',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('模态', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        Row(
          children: [
            SizedBox(
              width: 60,
              child: Text('输入:', style: theme.typography.body),
            ),
            for (final mod in allModalities) ...[
              Checkbox(
                checked: _inputModalities.contains(mod),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _inputModalities.add(mod);
                  } else {
                    _inputModalities.remove(mod);
                  }
                }),
                content: Text(labels[mod] ?? mod),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            SizedBox(
              width: 60,
              child: Text('输出:', style: theme.typography.body),
            ),
            for (final mod in allModalities) ...[
              Checkbox(
                checked: _outputModalities.contains(mod),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    _outputModalities.add(mod);
                  } else {
                    _outputModalities.remove(mod);
                  }
                }),
                content: Text(labels[mod] ?? mod),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Capability toggles
  // ---------------------------------------------------------------------------

  Widget _buildCapabilityToggles(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('能力', style: theme.typography.bodyStrong),
        const SizedBox(height: 8),
        _CapRow(
          label: '视觉理解',
          subtitle: '支持图像输入',
          icon: FluentIcons.red_eye,
          value: _supportsVision,
          onChanged: (v) => setState(() => _supportsVision = v),
        ),
        _CapRow(
          label: '函数/工具调用',
          subtitle: 'Function Calling / Tool Use',
          icon: FluentIcons.code,
          value: _supportsFunctionCalling,
          onChanged: (v) => setState(() => _supportsFunctionCalling = v),
        ),
        _CapRow(
          label: '并行函数调用',
          subtitle: '同时调用多个工具',
          icon: FluentIcons.split,
          value: _supportsParallelFunctionCalling,
          onChanged: (v) =>
              setState(() => _supportsParallelFunctionCalling = v),
        ),
        _CapRow(
          label: '深度推理',
          subtitle: 'Chain-of-Thought / Extended Thinking',
          icon: FluentIcons.lightbulb,
          value: _supportsReasoning,
          onChanged: (v) => setState(() => _supportsReasoning = v),
        ),
        _CapRow(
          label: '结构化输出 (JSON)',
          subtitle: 'Response Schema / JSON Mode',
          icon: FluentIcons.code,
          value: _supportsResponseSchema,
          onChanged: (v) => setState(() => _supportsResponseSchema = v),
        ),
        _CapRow(
          label: '联网搜索',
          subtitle: 'Web Search / Browsing',
          icon: FluentIcons.globe,
          value: _supportsWebSearch,
          onChanged: (v) => setState(() => _supportsWebSearch = v),
        ),
        _CapRow(
          label: '音频输入',
          subtitle: '直接接收音频数据',
          icon: FluentIcons.microphone,
          value: _supportsAudioInput,
          onChanged: (v) => setState(() => _supportsAudioInput = v),
        ),
        _CapRow(
          label: '音频输出',
          subtitle: '直接生成音频数据',
          icon: FluentIcons.volume3,
          value: _supportsAudioOutput,
          onChanged: (v) => setState(() => _supportsAudioOutput = v),
        ),
        _CapRow(
          label: '提示缓存',
          subtitle: 'Prompt Caching',
          icon: FluentIcons.database,
          value: _supportsPromptCaching,
          onChanged: (v) => setState(() => _supportsPromptCaching = v),
        ),
        _CapRow(
          label: '系统消息',
          subtitle: '支持 System Message',
          icon: FluentIcons.settings,
          value: _supportsSystemMessages,
          onChanged: (v) => setState(() => _supportsSystemMessages = v),
        ),
      ],
    );
  }
}

// =============================================================================
// Capability toggle row
// =============================================================================

class _CapRow extends StatelessWidget {
  const _CapRow({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.resources.textFillColorSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.typography.body),
                Text(
                  subtitle,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                  ),
                ),
              ],
            ),
          ),
          ToggleSwitch(checked: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// =============================================================================
// Search result tile
// =============================================================================

class _SearchResultTile extends StatelessWidget {
  const _SearchResultTile({required this.model, required this.theme});

  final AiModelInfo model;
  final FluentThemeData theme;

  @override
  Widget build(BuildContext context) {
    final b = theme.brightness;
    final ctxLabel = model.contextWindowLabel;
    return Row(
      children: [
        Expanded(
          child: Text(model.id, overflow: TextOverflow.ellipsis),
        ),
        if (ctxLabel.isNotEmpty) ...[
          const SizedBox(width: 6),
          _MiniTag(label: ctxLabel, color: AppColors.info(b)),
        ],
        if (model.supportsVision) ...[
          const SizedBox(width: 4),
          _MiniTag(label: '视觉', color: AppColors.providerGoogle(b)),
        ],
        if (model.supportsReasoning) ...[
          const SizedBox(width: 4),
          _MiniTag(label: '推理', color: AppColors.warning(b)),
        ],
      ],
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: FluentTheme.of(context)
            .typography
            .caption
            ?.copyWith(color: color, fontSize: 10),
      ),
    );
  }
}

// =============================================================================
// Preset chip
// =============================================================================

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.preset,
    required this.theme,
    required this.onTap,
  });

  final ModelCapabilityPreset preset;
  final FluentThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HoverButton(
      onPressed: onTap,
      builder: (context, states) {
        final hovered = states.isHovered;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: hovered
                ? theme.accentColor.withValues(alpha: 0.10)
                : theme.resources.subtleFillColorSecondary,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: hovered
                  ? theme.accentColor.withValues(alpha: 0.4)
                  : theme.resources.controlStrokeColorDefault,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(preset.icon, size: 13),
              const SizedBox(width: 5),
              Text(preset.name, style: theme.typography.caption),
            ],
          ),
        );
      },
    );
  }
}
