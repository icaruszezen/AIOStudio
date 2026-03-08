import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/anthropic_service.dart';
import '../../../core/services/ai/custom_service.dart';
import '../../../core/services/ai/openai_service.dart';
import '../../../core/services/ai/stability_service.dart';
import '../../../core/theme/app_theme.dart';

const _providerTypes = ['openai', 'anthropic', 'stability', 'custom'];

const _defaultBaseUrls = {
  'openai': 'https://api.openai.com',
  'anthropic': 'https://api.anthropic.com',
  'stability': 'https://api.stability.ai',
  'custom': '',
};

const _modelOptions = {
  'openai': [
    'gpt-4.1',
    'gpt-4.1-mini',
    'gpt-4.1-nano',
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-4',
    'gpt-3.5-turbo',
    'dall-e-3',
    'dall-e-2',
  ],
  'anthropic': [
    'claude-sonnet-4-20250514',
    'claude-4-opus-20250514',
    'claude-3-7-sonnet-20250219',
    'claude-3-5-sonnet-20241022',
    'claude-3-haiku-20240307',
    'claude-3-opus-20240229',
  ],
  'stability': [
    'stable-diffusion-xl-1024-v1-0',
    'stable-diffusion-v1-6',
    'stable-image-ultra',
    'stable-image-core',
  ],
};

class AiProviderDialog extends ConsumerStatefulWidget {
  const AiProviderDialog({super.key, this.existing});

  final AiProviderConfig? existing;

  static Future<bool?> show(BuildContext context,
      {AiProviderConfig? existing}) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AiProviderDialog(existing: existing),
    );
  }

  @override
  ConsumerState<AiProviderDialog> createState() => _AiProviderDialogState();
}

class _AiProviderDialogState extends ConsumerState<AiProviderDialog> {
  late String _type;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _baseUrlCtrl;
  String? _defaultModel;
  bool _isTesting = false;
  bool _isSubmitting = false;
  String? _testResult;
  bool? _testSuccess;

  // Model discovery state
  bool _isFetchingModels = false;
  List<AiModelInfo> _discoveredModels = [];
  String? _fetchError;

  bool get _isEditing => widget.existing != null;
  bool get _supportsDiscovery => _type == 'custom' || _type == 'openai';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?.type ?? 'openai';
    _nameCtrl = TextEditingController(text: e?.name ?? _defaultName(_type));
    _apiKeyCtrl = TextEditingController(text: e?.apiKey ?? '');
    _baseUrlCtrl = TextEditingController(
      text: e?.baseUrl ?? _defaultBaseUrls[_type] ?? '',
    );
    _defaultModel = e?.defaultModel;

    if (e != null && e.extraConfig != null) {
      _loadExistingModels(e.extraConfig!);
    }
  }

  void _loadExistingModels(String extraConfigJson) {
    try {
      final extra = jsonDecode(extraConfigJson) as Map<String, dynamic>;
      final discovered = extra['discovered_models'] as List<dynamic>?;
      if (discovered != null && discovered.isNotEmpty) {
        _discoveredModels = discovered
            .map((e) => AiModelInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  String _defaultName(String type) => switch (type) {
        'openai' => 'OpenAI',
        'anthropic' => 'Anthropic',
        'stability' => 'Stability AI',
        'custom' => '自定义服务商',
        _ => type,
      };

  String _typeLabel(String type) => switch (type) {
        'openai' => 'OpenAI',
        'anthropic' => 'Anthropic',
        'stability' => 'Stability AI',
        'custom' => '自定义 (OpenAI 兼容)',
        _ => type,
      };

  void _onTypeChanged(String? type) {
    if (type == null || type == _type) return;
    setState(() {
      _type = type;
      if (!_isEditing) {
        _nameCtrl.text = _defaultName(type);
        _baseUrlCtrl.text = _defaultBaseUrls[type] ?? '';
        _defaultModel = null;
        _discoveredModels = [];
        _fetchError = null;
      }
      _testResult = null;
      _testSuccess = null;
    });
  }

  List<String> get _currentModels => _modelOptions[_type] ?? [];

  // ---------------------------------------------------------------------------
  // Model Discovery
  // ---------------------------------------------------------------------------

  Future<void> _fetchModels() async {
    final baseUrl = _baseUrlCtrl.text.trim();
    if (baseUrl.isEmpty) {
      setState(() => _fetchError = '请先输入 API Base URL');
      return;
    }

    setState(() {
      _isFetchingModels = true;
      _fetchError = null;
    });

    try {
      final discovery = ref.read(modelDiscoveryServiceProvider);
      final apiKey = _apiKeyCtrl.text.trim();
      final models = await discovery.fetchModels(
        baseUrl: baseUrl,
        apiKey: apiKey.isNotEmpty ? apiKey : null,
      );
      if (mounted) {
        setState(() {
          _discoveredModels = models
              .map((m) => m.copyWith(isEnabled: true))
              .toList();
          _isFetchingModels = false;
          if (_discoveredModels.isNotEmpty && _defaultModel == null) {
            final chatModels = _discoveredModels
                .where((m) => m.isChatModel)
                .toList();
            if (chatModels.isNotEmpty) _defaultModel = chatModels.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fetchError = '$e';
          _isFetchingModels = false;
        });
      }
    }
  }

  void _toggleModel(int index, bool enabled) {
    setState(() {
      _discoveredModels[index] =
          _discoveredModels[index].copyWith(isEnabled: enabled);
    });
  }

  // ---------------------------------------------------------------------------
  // Connection Test
  // ---------------------------------------------------------------------------

  Future<void> _testConnection() async {
    final apiKey = _apiKeyCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();

    if (apiKey.isEmpty && _type != 'custom') {
      setState(() {
        _testResult = '请输入 API Key';
        _testSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _testResult = null;
      _testSuccess = null;
    });

    try {
      final effectiveBaseUrl = baseUrl.isNotEmpty ? baseUrl : null;
      final service = _createServiceForType(
        _type,
        'test-temp',
        apiKey,
        effectiveBaseUrl,
        _nameCtrl.text.trim(),
      );
      if (service == null) {
        setState(() {
          _testResult = '无法创建服务实例，请检查配置';
          _testSuccess = false;
        });
        return;
      }

      await service.testConnection();
      service.dispose();

      setState(() {
        _testResult = '连接成功';
        _testSuccess = true;
      });
    } catch (e) {
      setState(() {
        _testResult = '连接失败: $e';
        _testSuccess = false;
      });
    } finally {
      setState(() => _isTesting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  String? _buildExtraConfig() {
    if (_discoveredModels.isEmpty) return null;
    final data = {
      'discovered_models': _discoveredModels.map((m) => m.toJson()).toList(),
    };
    return jsonEncode(data);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        displayInfoBar(context,
            builder: (ctx, close) => InfoBar(
                  title: const Text('名称不能为空'),
                  severity: InfoBarSeverity.warning,
                  onClose: close,
                ));
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final dao = ref.read(aiProviderConfigDaoProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      final apiKey = _apiKeyCtrl.text.trim();
      final baseUrl = _baseUrlCtrl.text.trim();
      final extraConfig = _buildExtraConfig();

      if (_isEditing) {
        await dao.updateConfig(AiProviderConfigsCompanion(
          id: Value(widget.existing!.id),
          name: Value(name),
          type: Value(_type),
          apiKey: Value(apiKey.isNotEmpty ? apiKey : null),
          baseUrl: Value(baseUrl.isNotEmpty ? baseUrl : null),
          defaultModel: Value(_defaultModel),
          isEnabled: Value(widget.existing!.isEnabled),
          extraConfig: Value(extraConfig),
          createdAt: Value(widget.existing!.createdAt),
          updatedAt: Value(now),
        ));
      } else {
        await dao.insertConfig(AiProviderConfigsCompanion(
          id: Value(const Uuid().v4()),
          name: Value(name),
          type: Value(_type),
          apiKey: Value(apiKey.isNotEmpty ? apiKey : null),
          baseUrl: Value(baseUrl.isNotEmpty ? baseUrl : null),
          defaultModel: Value(_defaultModel),
          isEnabled: const Value(true),
          extraConfig: Value(extraConfig),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        displayInfoBar(context,
            builder: (ctx, close) => InfoBar(
                  title: Text(_isEditing ? '保存失败' : '添加失败'),
                  content: Text('$e'),
                  severity: InfoBarSeverity.error,
                  onClose: close,
                ));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Text(_isEditing ? '编辑服务商' : '添加服务商'),
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTypeSelector(),
            const SizedBox(height: 14),
            _buildNameField(),
            const SizedBox(height: 14),
            _buildApiKeyField(),
            const SizedBox(height: 14),
            _buildBaseUrlField(),
            const SizedBox(height: 14),

            // For built-in types: simple ComboBox model selector
            if (!_supportsDiscovery && _currentModels.isNotEmpty) ...[
              _buildSimpleModelSelector(),
              const SizedBox(height: 14),
            ],

            // For OpenAI-compatible types: discovery + model list
            if (_supportsDiscovery) ...[
              _buildFetchModelsButton(theme),
              if (_fetchError != null) ...[
                const SizedBox(height: 8),
                _buildFetchError(theme),
              ],
              if (_discoveredModels.isNotEmpty) ...[
                const SizedBox(height: 14),
                _buildDiscoveredModelList(theme),
                const SizedBox(height: 14),
                _buildDefaultModelFromDiscovered(),
              ],
              const SizedBox(height: 14),
            ],

            _buildTestConnectionRow(theme),
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Text(_isEditing ? '保存' : '添加'),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    return InfoLabel(
      label: '服务商类型',
      child: ComboBox<String>(
        value: _type,
        items: _providerTypes
            .map(
                (t) => ComboBoxItem(value: t, child: Text(_typeLabel(t))))
            .toList(),
        onChanged: _isEditing ? null : _onTypeChanged,
        isExpanded: true,
      ),
    );
  }

  Widget _buildNameField() {
    return InfoLabel(
      label: '名称',
      child: TextBox(
        controller: _nameCtrl,
        placeholder: '输入显示名称',
      ),
    );
  }

  Widget _buildApiKeyField() {
    return InfoLabel(
      label: 'API Key',
      child: PasswordBox(
        controller: _apiKeyCtrl,
        placeholder: '输入 API Key',
        revealMode: PasswordRevealMode.peekAlways,
      ),
    );
  }

  Widget _buildBaseUrlField() {
    return InfoLabel(
      label: 'API Base URL',
      child: TextBox(
        controller: _baseUrlCtrl,
        placeholder: '可选，自定义 API 端点',
      ),
    );
  }

  Widget _buildSimpleModelSelector() {
    return InfoLabel(
      label: '默认模型',
      child: ComboBox<String>(
        value: _defaultModel,
        placeholder: const Text('选择默认模型'),
        items: _currentModels
            .map((m) => ComboBoxItem(value: m, child: Text(m)))
            .toList(),
        onChanged: (val) => setState(() => _defaultModel = val),
        isExpanded: true,
      ),
    );
  }

  Widget _buildFetchModelsButton(FluentThemeData theme) {
    return Row(
      children: [
        Button(
          onPressed: _isFetchingModels ? null : _fetchModels,
          child: _isFetchingModels
              ? const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                        width: 14,
                        height: 14,
                        child: ProgressRing(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('正在获取...'),
                  ],
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.download, size: 14),
                    SizedBox(width: 6),
                    Text('获取模型列表'),
                  ],
                ),
        ),
        if (_discoveredModels.isNotEmpty) ...[
          const SizedBox(width: 12),
          Text(
            '已发现 ${_discoveredModels.length} 个模型',
            style: theme.typography.caption?.copyWith(
              color: AppColors.success(theme.brightness),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFetchError(FluentThemeData theme) {
    return InfoBar(
      title: const Text('获取模型失败'),
      content: Text(
        _fetchError!,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      severity: InfoBarSeverity.error,
      isLong: true,
    );
  }

  Widget _buildDiscoveredModelList(FluentThemeData theme) {
    return InfoLabel(
      label: '模型列表 ($_enabledCount/${_discoveredModels.length} 已启用)',
      child: Container(
        constraints: const BoxConstraints(maxHeight: 240),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.resources.controlStrokeColorDefault,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: _discoveredModels.length,
          separatorBuilder: (_, __) => const Divider(
            style: DividerThemeData(
              horizontalMargin: EdgeInsets.symmetric(horizontal: 12),
            ),
          ),
          itemBuilder: (context, index) {
            final model = _discoveredModels[index];
            return _ModelRow(
              model: model,
              onToggle: (v) => _toggleModel(index, v),
            );
          },
        ),
      ),
    );
  }

  int get _enabledCount =>
      _discoveredModels.where((m) => m.isEnabled).length;

  Widget _buildDefaultModelFromDiscovered() {
    final enabledModels =
        _discoveredModels.where((m) => m.isEnabled).toList();
    if (enabledModels.isEmpty) return const SizedBox.shrink();

    if (_defaultModel != null &&
        !enabledModels.any((m) => m.id == _defaultModel)) {
      _defaultModel = enabledModels.first.id;
    }

    return InfoLabel(
      label: '默认模型',
      child: ComboBox<String>(
        value: _defaultModel,
        placeholder: const Text('选择默认模型'),
        items: enabledModels
            .map((m) => ComboBoxItem(value: m.id, child: Text(m.id)))
            .toList(),
        onChanged: (val) => setState(() => _defaultModel = val),
        isExpanded: true,
      ),
    );
  }

  Widget _buildTestConnectionRow(FluentThemeData theme) {
    return Row(
      children: [
        Button(
          onPressed: _isTesting ? null : _testConnection,
          child: _isTesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.plug_connected, size: 14),
                    SizedBox(width: 6),
                    Text('测试连接'),
                  ],
                ),
        ),
        if (_testResult != null) ...[
          const SizedBox(width: 12),
          Icon(
            _testSuccess == true
                ? FluentIcons.check_mark
                : FluentIcons.error_badge,
            size: 14,
            color: _testSuccess == true
                ? AppColors.success(theme.brightness)
                : AppColors.error(theme.brightness),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _testResult!,
              style: theme.typography.caption?.copyWith(
                color: _testSuccess == true
                    ? AppColors.success(theme.brightness)
                    : AppColors.error(theme.brightness),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Model row widget with capability badges
// ---------------------------------------------------------------------------

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.model, required this.onToggle});

  final AiModelInfo model;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  model.id,
                  style: theme.typography.body?.copyWith(
                    color: model.isEnabled
                        ? null
                        : theme.resources.textFillColorDisabled,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: 4,
                  runSpacing: 2,
                  children: _buildBadges(theme),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ToggleSwitch(
            checked: model.isEnabled,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBadges(FluentThemeData theme) {
    final badges = <Widget>[];
    final b = theme.brightness;

    // Mode badge
    final modeLabel = switch (model.mode) {
      'chat' => '对话',
      'image_generation' => '图片生成',
      'embedding' => '嵌入',
      'audio_transcription' => '语音转录',
      'audio_speech' => '语音合成',
      _ => model.mode,
    };
    badges.add(_Badge(label: modeLabel, color: AppColors.info(b)));

    // Context window
    if (model.contextWindowLabel.isNotEmpty) {
      badges.add(_Badge(
        label: model.contextWindowLabel,
        color: AppColors.providerOpenAI(b),
      ));
    }

    // Vision
    if (model.supportsVision) {
      badges.add(_Badge(label: '视觉', color: AppColors.providerGoogle(b)));
    }

    // Function calling
    if (model.supportsFunctionCalling) {
      badges.add(
          _Badge(label: '函数调用', color: AppColors.providerAnthropic(b)));
    }

    // Reasoning
    if (model.supportsReasoning) {
      badges.add(_Badge(label: '推理', color: AppColors.warning(b)));
    }

    // Multi-modal input indicators (beyond text)
    for (final mod in model.inputModalities) {
      if (mod == 'text') continue;
      if (mod == 'image' && model.supportsVision) continue;
      badges.add(_Badge(
        label: _modalityLabel(mod),
        color: AppColors.providerCustom(b),
      ));
    }

    // Output modalities beyond text
    for (final mod in model.outputModalities) {
      if (mod == 'text') continue;
      badges.add(_Badge(
        label: '输出${_modalityLabel(mod)}',
        color: AppColors.success(b),
      ));
    }

    if (badges.isEmpty) {
      badges.add(_Badge(label: '未知', color: AppColors.pending(b)));
    }

    return badges;
  }

  static String _modalityLabel(String mod) => switch (mod) {
        'text' => '文本',
        'image' => '图像',
        'audio' => '音频',
        'video' => '视频',
        _ => mod,
      };
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        label,
        style: FluentTheme.of(context).typography.caption?.copyWith(
              color: color,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Temp service creation for connection testing.
// ---------------------------------------------------------------------------

AiService? _createServiceForType(
  String type,
  String id,
  String apiKey,
  String? baseUrl,
  String name,
) {
  switch (type) {
    case 'openai':
      return OpenAiService(
        providerId: id,
        apiKey: apiKey,
        baseUrl: baseUrl ?? 'https://api.openai.com',
      );
    case 'anthropic':
      return AnthropicService(
        providerId: id,
        apiKey: apiKey,
        baseUrl: baseUrl ?? 'https://api.anthropic.com',
      );
    case 'stability':
      return StabilityService(
        providerId: id,
        apiKey: apiKey,
        baseUrl: baseUrl ?? 'https://api.stability.ai',
      );
    case 'custom':
      if (baseUrl == null || baseUrl.isEmpty) return null;
      return CustomService.fromStringModels(
        providerId: id,
        providerName: name,
        baseUrl: baseUrl,
        apiKey: apiKey.isNotEmpty ? apiKey : null,
        models: ['default'],
      );
    default:
      return null;
  }
}
