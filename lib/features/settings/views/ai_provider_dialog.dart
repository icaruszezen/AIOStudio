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
import '../../../core/services/ai/provider_presets.dart';
import '../../../core/services/ai/stability_service.dart';
import '../../../core/theme/app_theme.dart';
import 'model_capability_dialog.dart';

class AiProviderDialog extends ConsumerStatefulWidget {
  const AiProviderDialog({super.key, this.existing});

  final AiProviderConfig? existing;

  static Future<bool?> show(
    BuildContext context, {
    AiProviderConfig? existing,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AiProviderDialog(existing: existing),
    );
  }

  @override
  ConsumerState<AiProviderDialog> createState() => _AiProviderDialogState();
}

class _AiProviderDialogState extends ConsumerState<AiProviderDialog> {
  int _step = 0;
  ProviderPreset? _selectedPreset;
  bool _shouldPersistPreset = false;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _baseUrlCtrl;
  late final TextEditingController _defaultModelCtrl;
  String? _defaultModel;

  bool _isTesting = false;
  String? _testResult;
  bool? _testSuccess;

  bool _isFetchingModels = false;
  List<AiModelInfo> _discoveredModels = [];
  String? _fetchError;

  bool _isSubmitting = false;
  String _searchQuery = '';

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _apiKeyCtrl = TextEditingController();
    _baseUrlCtrl = TextEditingController();
    _defaultModelCtrl = TextEditingController();

    if (_isEditing) {
      _loadExisting();
      _step = 1;
    }
  }

  void _loadExisting() {
    final e = widget.existing!;
    final storedPresetId = ProviderPresets.storedPresetId(e.extraConfig);
    final presetId = ProviderPresets.resolvePresetId(
      e.type,
      e.baseUrl,
      e.extraConfig,
    );
    _selectedPreset = ProviderPresets.getById(presetId);
    _shouldPersistPreset = storedPresetId != null;

    _nameCtrl.text = e.name;
    _apiKeyCtrl.text = e.apiKey ?? '';
    _baseUrlCtrl.text = e.baseUrl ?? '';
    _setDefaultModel(e.defaultModel);

    if (e.extraConfig != null) {
      try {
        final extra = jsonDecode(e.extraConfig!) as Map<String, dynamic>;
        final discovered = extra['discovered_models'] as List<dynamic>?;
        if (discovered != null && discovered.isNotEmpty) {
          _discoveredModels = discovered
              .map((e) => AiModelInfo.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}
    }

    if (_discoveredModels.isEmpty) {
      _initModelsFromPreset();
    }
  }

  /// Populates [_discoveredModels] from the preset's default models enriched
  /// with capability data from the registry. Called when no persisted
  /// `discovered_models` exist yet.
  Future<void> _initModelsFromPreset() async {
    final preset = _selectedPreset;
    if (preset == null || preset.defaultModels.isEmpty) return;

    final registry = ref.read(modelCapabilityRegistryProvider);
    if (!registry.isLoaded) await registry.load();

    if (!mounted) return;
    setState(() {
      _discoveredModels = preset.defaultModels.map((id) {
        final auto = registry.lookup(id);
        return auto?.copyWith(isEnabled: true) ??
            AiModelInfo(id: id, isEnabled: true);
      }).toList();
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _defaultModelCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  void _selectPreset(ProviderPreset preset) {
    setState(() {
      _selectedPreset = preset;
      _shouldPersistPreset = true;
      _nameCtrl.text = preset.name;
      _baseUrlCtrl.text = preset.defaultBaseUrl;
      _apiKeyCtrl.clear();
      _setDefaultModel(
        preset.defaultModels.isNotEmpty ? preset.defaultModels.first : null,
      );
      _discoveredModels = [];
      _fetchError = null;
      _testResult = null;
      _testSuccess = null;
      _step = 1;
    });
  }

  void _goToVerify() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showWarning('名称不能为空');
      return;
    }

    final preset = _selectedPreset;
    if (preset == null) return;

    if (preset.requiresApiKey && _apiKeyCtrl.text.trim().isEmpty) {
      _showWarning('请输入 API Key');
      return;
    }

    if (preset.serviceType == 'custom' && _baseUrlCtrl.text.trim().isEmpty) {
      _showWarning('请输入 API Base URL');
      return;
    }

    setState(() {
      _step = 2;
      _testResult = null;
      _testSuccess = null;
    });

    _autoVerify();
  }

  Future<void> _autoVerify() async {
    await _testConnection();
    if (_testSuccess == true) {
      final preset = _selectedPreset;
      if (preset != null && preset.supportsModelDiscovery) {
        await _fetchModels();
      }
    }
  }

  void _showWarning(String message) {
    if (!mounted) return;
    displayInfoBar(
      context,
      builder: (ctx, close) => InfoBar(
        title: Text(message),
        severity: InfoBarSeverity.warning,
        onClose: close,
      ),
    );
  }

  String? _normalizeModelId(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) return null;
    return normalized;
  }

  void _setDefaultModel(String? value) {
    final normalized = _normalizeModelId(value);
    _defaultModel = normalized;
    final text = normalized ?? '';
    if (_defaultModelCtrl.text != text) {
      _defaultModelCtrl.text = text;
    }
  }

  bool _hasModelSource(ProviderPreset preset) {
    if (!preset.supportsModelDiscovery) return true;
    final hasDiscoveredModels = _discoveredModels.any((m) => m.isEnabled);
    return hasDiscoveredModels ||
        _normalizeModelId(_defaultModelCtrl.text) != null;
  }

  // ---------------------------------------------------------------------------
  // Connection Test
  // ---------------------------------------------------------------------------

  Future<void> _testConnection() async {
    final apiKey = _apiKeyCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    final preset = _selectedPreset;
    if (preset == null) return;

    if (apiKey.isEmpty && preset.requiresApiKey) {
      setState(() {
        _testResult = 'API Key 未填写';
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
      final service = _createServiceForType(
        preset.serviceType,
        'test-temp',
        apiKey,
        baseUrl.isNotEmpty ? baseUrl : null,
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

      if (mounted) {
        setState(() {
          _testResult = '连接成功';
          _testSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testResult = '连接失败: $e';
          _testSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isTesting = false);
    }
  }

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
            if (chatModels.isNotEmpty) {
              _setDefaultModel(chatModels.first.id);
            } else {
              _setDefaultModel(_discoveredModels.first.id);
            }
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
      _discoveredModels[index] = _discoveredModels[index].copyWith(
        isEnabled: enabled,
      );
    });
  }

  Future<void> _editModelCapability(int index) async {
    final result = await ModelCapabilityDialog.show(
      context,
      model: _discoveredModels[index],
    );
    if (result != null && mounted) {
      setState(() => _discoveredModels[index] = result);
    }
  }

  Future<void> _addCustomModel() async {
    final idCtrl = TextEditingController();
    final modelId = await showDialog<String>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('添加自定义模型'),
        content: InfoLabel(
          label: '模型 ID',
          child: TextBox(
            controller: idCtrl,
            placeholder: '输入模型 ID，如 my-custom-model',
            autofocus: true,
          ),
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final id = idCtrl.text.trim();
              if (id.isNotEmpty) Navigator.of(ctx).pop(id);
            },
            child: const Text('添加'),
          ),
        ],
      ),
    );
    idCtrl.dispose();

    if (modelId == null || modelId.isEmpty || !mounted) return;

    if (_discoveredModels.any((m) => m.id == modelId)) {
      _showWarning('模型 "$modelId" 已存在');
      return;
    }

    final registry = ref.read(modelCapabilityRegistryProvider);
    if (!registry.isLoaded) await registry.load();
    final auto = registry.lookup(modelId);
    final newModel =
        auto?.copyWith(isEnabled: true) ?? AiModelInfo(id: modelId);

    final edited = await ModelCapabilityDialog.show(context, model: newModel);
    if (edited != null && mounted) {
      setState(() => _discoveredModels.add(edited));
    }
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  String? _buildExtraConfig() {
    final data = <String, dynamic>{};

    if (_shouldPersistPreset && _selectedPreset != null) {
      data['preset'] = _selectedPreset!.id;
    }
    if (_discoveredModels.isNotEmpty) {
      data['discovered_models'] = _discoveredModels
          .map((m) => m.toJson())
          .toList();
    }
    if (data.isEmpty) return null;
    return jsonEncode(data);
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showWarning('名称不能为空');
      return;
    }

    final preset = _selectedPreset;
    if (preset == null) return;
    final apiKey = _apiKeyCtrl.text.trim();
    final baseUrl = _baseUrlCtrl.text.trim();
    _setDefaultModel(_defaultModelCtrl.text);

    if (preset.requiresApiKey && apiKey.isEmpty) {
      _showWarning('请输入 API Key');
      return;
    }

    if (preset.serviceType == 'custom' && baseUrl.isEmpty) {
      _showWarning('请输入 API Base URL');
      return;
    }

    if (!_hasModelSource(preset)) {
      _showWarning('请至少填写默认模型，或先获取模型列表');
      return;
    }

    if (_discoveredModels.isEmpty && preset.defaultModels.isNotEmpty) {
      await _initModelsFromPreset();
    }

    setState(() => _isSubmitting = true);

    try {
      final dao = ref.read(aiProviderConfigDaoProvider);
      final now = DateTime.now().millisecondsSinceEpoch;
      final extraConfig = _buildExtraConfig();

      if (_isEditing) {
        await dao.updateConfig(
          AiProviderConfigsCompanion(
            id: Value(widget.existing!.id),
            name: Value(name),
            type: Value(preset.serviceType),
            apiKey: Value(apiKey.isNotEmpty ? apiKey : null),
            baseUrl: Value(baseUrl.isNotEmpty ? baseUrl : null),
            defaultModel: Value(_defaultModel),
            isEnabled: Value(widget.existing!.isEnabled),
            extraConfig: Value(extraConfig),
            createdAt: Value(widget.existing!.createdAt),
            updatedAt: Value(now),
          ),
        );
      } else {
        await dao.insertConfig(
          AiProviderConfigsCompanion(
            id: Value(const Uuid().v4()),
            name: Value(name),
            type: Value(preset.serviceType),
            apiKey: Value(apiKey.isNotEmpty ? apiKey : null),
            baseUrl: Value(baseUrl.isNotEmpty ? baseUrl : null),
            defaultModel: Value(_defaultModel),
            isEnabled: const Value(true),
            extraConfig: Value(extraConfig),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (ctx, close) => InfoBar(
            title: Text(_isEditing ? '保存失败' : '添加失败'),
            content: Text('$e'),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
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
      constraints: BoxConstraints(
        maxWidth: 720,
        maxHeight: _isEditing ? 700 : 580,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isEditing) ...[
            _buildStepIndicator(theme),
            const SizedBox(height: 16),
          ],
          Flexible(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (_step) {
                0 => _buildSelectionStep(theme),
                1 => _buildConfigStep(theme),
                2 => _buildVerifyStep(theme),
                _ => const SizedBox.shrink(),
              },
            ),
          ),
        ],
      ),
      actions: _buildActions(),
    );
  }

  // ---------------------------------------------------------------------------
  // Step Indicator
  // ---------------------------------------------------------------------------

  Widget _buildStepIndicator(FluentThemeData theme) {
    const labels = ['选择服务商', '配置', '验证'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) ...[
            Expanded(
              child: Container(
                height: 1,
                color: i <= _step
                    ? theme.accentColor
                    : theme.resources.controlStrokeColorDefault,
              ),
            ),
          ],
          _StepDot(
            index: i,
            label: labels[i],
            isActive: i == _step,
            isCompleted: i < _step,
            theme: theme,
          ),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 0 – Provider Selection
  // ---------------------------------------------------------------------------

  Widget _buildSelectionStep(FluentThemeData theme) {
    final filtered = _searchQuery.isEmpty
        ? ProviderPresets.all
        : ProviderPresets.search(_searchQuery);

    final grouped = <ProviderCategory, List<ProviderPreset>>{};
    for (final p in filtered) {
      (grouped[p.category] ??= []).add(p);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextBox(
          placeholder: '搜索服务商...',
          prefix: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(FluentIcons.search, size: 14),
          ),
          onChanged: (v) => setState(() => _searchQuery = v),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final category in ProviderCategory.values)
                  if (grouped.containsKey(category)) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 8),
                      child: Text(
                        category.label,
                        style: theme.typography.bodyStrong,
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preset in grouped[category]!)
                          _PresetCard(
                            preset: preset,
                            theme: theme,
                            onTap: () => _selectPreset(preset),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1 – Configuration
  // ---------------------------------------------------------------------------

  Widget _buildConfigStep(FluentThemeData theme) {
    final preset = _selectedPreset;
    if (preset == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPresetHeader(preset, theme),
          const SizedBox(height: 20),
          InfoLabel(
            label: '名称',
            child: TextBox(controller: _nameCtrl, placeholder: '输入显示名称'),
          ),
          const SizedBox(height: 14),
          InfoLabel(
            label: 'API Key${preset.requiresApiKey ? '' : ' (可选)'}',
            child: PasswordBox(
              controller: _apiKeyCtrl,
              placeholder: preset.requiresApiKey ? '输入 API Key' : '可选',
              revealMode: PasswordRevealMode.peekAlways,
            ),
          ),
          const SizedBox(height: 14),
          InfoLabel(
            label: 'API Base URL',
            child: TextBox(
              controller: _baseUrlCtrl,
              placeholder: preset.defaultBaseUrl.isNotEmpty
                  ? preset.defaultBaseUrl
                  : '输入 API 端点地址',
            ),
          ),
          if (preset.supportsModelDiscovery) ...[
            const SizedBox(height: 14),
            InfoLabel(
              label: '默认模型',
              child: TextBox(
                controller: _defaultModelCtrl,
                placeholder: preset.defaultModels.isNotEmpty
                    ? preset.defaultModels.first
                    : '发现失败时手动填写模型 ID',
                onChanged: (value) => _defaultModel = _normalizeModelId(value),
              ),
            ),
            if (preset.defaultModels.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                '预设示例: ${preset.defaultModels.take(3).join(' / ')}',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ],
          if (!preset.supportsModelDiscovery &&
              !_isEditing &&
              preset.defaultModels.isNotEmpty) ...[
            const SizedBox(height: 14),
            InfoLabel(
              label: '默认模型',
              child: ComboBox<String>(
                value: _defaultModel,
                placeholder: const Text('选择默认模型'),
                items: preset.defaultModels
                    .map((m) => ComboBoxItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) => setState(() => _setDefaultModel(val)),
                isExpanded: true,
              ),
            ),
          ],
          if (_isEditing) ...[
            const SizedBox(height: 20),
            _buildModelManagementSection(theme),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Model management (inline in config step when editing)
  // ---------------------------------------------------------------------------

  Widget _buildModelManagementSection(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(FluentIcons.list, size: 16),
            const SizedBox(width: 8),
            Text('可用模型', style: theme.typography.bodyStrong),
            const Spacer(),
            if (_selectedPreset?.supportsModelDiscovery ?? false)
              Button(
                onPressed: _isFetchingModels ? null : _fetchModels,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isFetchingModels)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: ProgressRing(strokeWidth: 2),
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(FluentIcons.download, size: 12),
                      ),
                    Text(_isFetchingModels ? '获取中...' : '获取模型列表'),
                  ],
                ),
              ),
            const SizedBox(width: 6),
            Button(
              onPressed: _addCustomModel,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.add, size: 12),
                  SizedBox(width: 6),
                  Text('添加模型'),
                ],
              ),
            ),
          ],
        ),
        if (_fetchError != null) ...[
          const SizedBox(height: 8),
          _buildFetchError(theme),
        ],
        const SizedBox(height: 8),
        if (_discoveredModels.isNotEmpty) ...[
          _buildDiscoveredModelList(theme),
          const SizedBox(height: 14),
          _buildDefaultModelFromDiscovered(),
        ] else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.resources.controlStrokeColorDefault,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Center(
              child: Text(
                '暂无模型，请获取模型列表或手动添加',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPresetHeader(ProviderPreset preset, FluentThemeData theme) {
    final color = preset.color(theme.brightness);
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(preset.icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(preset.name, style: theme.typography.bodyStrong),
              Text(
                preset.description,
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
            ],
          ),
        ),
        if (!_isEditing)
          Button(
            onPressed: () => setState(() {
              _step = 0;
              _searchQuery = '';
            }),
            child: const Text('更换'),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2 – Verify & Model Discovery
  // ---------------------------------------------------------------------------

  Widget _buildVerifyStep(FluentThemeData theme) {
    final showAddModel =
        !_isTesting && !_isFetchingModels && _testSuccess == true;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildConnectionStatus(theme),
          const SizedBox(height: 16),
          if (_isFetchingModels) _buildModelLoading(theme),
          if (_fetchError != null) ...[
            _buildFetchError(theme),
            const SizedBox(height: 12),
          ],
          if (_discoveredModels.isNotEmpty) ...[
            _buildDiscoveredModelList(theme),
            const SizedBox(height: 14),
            _buildDefaultModelFromDiscovered(),
          ],
          if (!_isTesting &&
              !_isFetchingModels &&
              _discoveredModels.isEmpty &&
              _testSuccess == true &&
              (_selectedPreset?.supportsModelDiscovery ?? false)) ...[
            const SizedBox(height: 8),
            _buildManualFetchButton(theme),
          ],
          if (showAddModel && _discoveredModels.isEmpty) ...[
            const SizedBox(height: 8),
            Button(
              onPressed: _addCustomModel,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.add, size: 12),
                  SizedBox(width: 6),
                  Text('手动添加模型'),
                ],
              ),
            ),
          ],
          if (!_isTesting && _testSuccess != true && !_isFetchingModels) ...[
            const SizedBox(height: 8),
            _buildRetryButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectionStatus(FluentThemeData theme) {
    if (_isTesting) {
      return Row(
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Text('正在测试连接...', style: theme.typography.body),
        ],
      );
    }

    if (_testResult == null) return const SizedBox.shrink();

    final isSuccess = _testSuccess == true;
    final color = isSuccess
        ? AppColors.success(theme.brightness)
        : AppColors.error(theme.brightness);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            isSuccess ? FluentIcons.check_mark : FluentIcons.error_badge,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _testResult!,
              style: theme.typography.body?.copyWith(color: color),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelLoading(FluentThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text('正在获取模型列表...', style: theme.typography.body),
        ],
      ),
    );
  }

  Widget _buildFetchError(FluentThemeData theme) {
    return InfoBar(
      title: const Text('获取模型失败'),
      content: Text(_fetchError!, maxLines: 2, overflow: TextOverflow.ellipsis),
      severity: InfoBarSeverity.warning,
      isLong: true,
    );
  }

  Widget _buildManualFetchButton(FluentThemeData theme) {
    return Button(
      onPressed: _isFetchingModels ? null : _fetchModels,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.download, size: 14),
          SizedBox(width: 6),
          Text('手动获取模型列表'),
        ],
      ),
    );
  }

  Widget _buildRetryButton() {
    return Button(
      onPressed: _autoVerify,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.plug_connected, size: 14),
          SizedBox(width: 6),
          Text('重新验证'),
        ],
      ),
    );
  }

  int get _enabledCount => _discoveredModels.where((m) => m.isEnabled).length;

  Widget _buildDiscoveredModelList(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoLabel(
          label: '模型列表 ($_enabledCount/${_discoveredModels.length} 已启用)',
          child: Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              border:
                  Border.all(color: theme.resources.controlStrokeColorDefault),
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
                  onEdit: () => _editModelCapability(index),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Button(
          onPressed: _addCustomModel,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.add, size: 12),
              SizedBox(width: 6),
              Text('手动添加模型'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultModelFromDiscovered() {
    final enabledModels = _discoveredModels.where((m) => m.isEnabled).toList();
    if (enabledModels.isEmpty) return const SizedBox.shrink();

    if (_defaultModel != null &&
        !enabledModels.any((m) => m.id == _defaultModel)) {
      _setDefaultModel(enabledModels.first.id);
    }

    return InfoLabel(
      label: '默认模型',
      child: ComboBox<String>(
        value: _defaultModel,
        placeholder: const Text('选择默认模型'),
        items: enabledModels
            .map((m) => ComboBoxItem(value: m.id, child: Text(m.id)))
            .toList(),
        onChanged: (val) => setState(() => _setDefaultModel(val)),
        isExpanded: true,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  List<Widget> _buildActions() {
    return switch (_step) {
      0 => [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
      1 => [
        if (!_isEditing)
          Button(
            onPressed: () => setState(() {
              _step = 0;
              _searchQuery = '';
            }),
            child: const Text('上一步'),
          ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        if (_isEditing)
          FilledButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: ProgressRing(strokeWidth: 2),
                  )
                : const Text('保存'),
          )
        else
          FilledButton(onPressed: _goToVerify, child: const Text('下一步')),
      ],
      2 => [
        Button(
          onPressed: _isSubmitting ? null : () => setState(() => _step = 1),
          child: const Text('上一步'),
        ),
        Button(
          onPressed: _isSubmitting ? null : _submit,
          child: const Text('跳过验证'),
        ),
        FilledButton(
          onPressed: (_isSubmitting || _testSuccess != true) ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : Text(_isEditing ? '保存' : '完成'),
        ),
      ],
      _ => [],
    };
  }
}

// =============================================================================
// Step indicator dot
// =============================================================================

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.label,
    required this.isActive,
    required this.isCompleted,
    required this.theme,
  });

  final int index;
  final String label;
  final bool isActive;
  final bool isCompleted;
  final FluentThemeData theme;

  @override
  Widget build(BuildContext context) {
    final color = (isActive || isCompleted)
        ? theme.accentColor
        : theme.resources.textFillColorSecondary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: (isActive || isCompleted)
                ? color
                : color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isCompleted
                ? const Icon(
                    FluentIcons.check_mark,
                    size: 10,
                    color: Colors.white,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: (isActive || isCompleted) ? Colors.white : color,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: color,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Preset card for step 0
// =============================================================================

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.theme,
    required this.onTap,
  });

  final ProviderPreset preset;
  final FluentThemeData theme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = preset.color(theme.brightness);
    return SizedBox(
      width: 210,
      child: HoverButton(
        onPressed: onTap,
        builder: (context, states) {
          final hovered = states.isHovered;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: hovered
                  ? theme.resources.subtleFillColorSecondary
                  : theme.resources.subtleFillColorTransparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: hovered
                    ? color.withValues(alpha: 0.5)
                    : theme.resources.controlStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(preset.icon, size: 18, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        preset.name,
                        style: theme.typography.bodyStrong,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        preset.description,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Model row widget with capability badges
// =============================================================================

class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.onToggle,
    this.onEdit,
  });

  final AiModelInfo model;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onEdit;

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
                Wrap(spacing: 4, runSpacing: 2, children: _buildBadges(theme)),
              ],
            ),
          ),
          const SizedBox(width: 4),
          if (onEdit != null)
            IconButton(
              icon: Icon(
                FluentIcons.edit,
                size: 12,
                color: theme.resources.textFillColorSecondary,
              ),
              onPressed: onEdit,
            ),
          const SizedBox(width: 4),
          ToggleSwitch(checked: model.isEnabled, onChanged: onToggle),
        ],
      ),
    );
  }

  List<Widget> _buildBadges(FluentThemeData theme) {
    final badges = <Widget>[];
    final b = theme.brightness;

    final modeLabel = switch (model.mode) {
      'chat' => '对话',
      'image_generation' => '图片生成',
      'embedding' => '嵌入',
      'audio_transcription' => '语音转录',
      'audio_speech' => '语音合成',
      'completion' => '补全',
      'moderation' => '审核',
      'rerank' => '重排序',
      _ => model.mode,
    };
    badges.add(_Badge(label: modeLabel, color: AppColors.info(b)));

    if (model.contextWindowLabel.isNotEmpty) {
      badges.add(
        _Badge(
          label: model.contextWindowLabel,
          color: AppColors.providerOpenAI(b),
        ),
      );
    }
    if (model.supportsVision) {
      badges.add(_Badge(label: '视觉', color: AppColors.providerGoogle(b)));
    }
    if (model.supportsFunctionCalling) {
      badges.add(_Badge(label: '函数调用', color: AppColors.providerAnthropic(b)));
    }
    if (model.supportsReasoning) {
      badges.add(_Badge(label: '推理', color: AppColors.warning(b)));
    }
    if (model.supportsResponseSchema) {
      badges.add(_Badge(label: 'JSON', color: AppColors.providerCustom(b)));
    }
    if (model.supportsWebSearch) {
      badges.add(_Badge(label: '联网', color: AppColors.chat(b)));
    }
    if (model.supportsAudioInput) {
      badges.add(_Badge(label: '音频输入', color: AppColors.audio(b)));
    }
    if (model.supportsAudioOutput) {
      badges.add(_Badge(label: '音频输出', color: AppColors.audio(b)));
    }
    if (model.supportsPromptCaching) {
      badges.add(_Badge(label: '缓存', color: AppColors.neutral(b)));
    }

    for (final mod in model.inputModalities) {
      if (mod == 'text') continue;
      if (mod == 'image' && model.supportsVision) continue;
      if (mod == 'audio' && model.supportsAudioInput) continue;
      badges.add(
        _Badge(label: _modalityLabel(mod), color: AppColors.providerCustom(b)),
      );
    }

    for (final mod in model.outputModalities) {
      if (mod == 'text') continue;
      if (mod == 'audio' && model.supportsAudioOutput) continue;
      badges.add(
        _Badge(label: '输出${_modalityLabel(mod)}', color: AppColors.success(b)),
      );
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
        style: FluentTheme.of(
          context,
        ).typography.caption?.copyWith(color: color),
      ),
    );
  }
}

// =============================================================================
// Service factory for connection testing
// =============================================================================

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
