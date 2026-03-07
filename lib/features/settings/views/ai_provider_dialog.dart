import 'package:drift/drift.dart' show Value;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
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

  static Future<bool?> show(BuildContext context, {AiProviderConfig? existing}) {
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
  late final TextEditingController _extraConfigCtrl;
  String? _defaultModel;
  bool _isTesting = false;
  bool _isSubmitting = false;
  String? _testResult;
  bool? _testSuccess;

  bool get _isEditing => widget.existing != null;

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
    _extraConfigCtrl = TextEditingController(text: e?.extraConfig ?? '');
    _defaultModel = e?.defaultModel;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _apiKeyCtrl.dispose();
    _baseUrlCtrl.dispose();
    _extraConfigCtrl.dispose();
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
      }
      _testResult = null;
      _testSuccess = null;
    });
  }

  List<String> get _currentModels =>
      _modelOptions[_type] ?? [];

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

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      if (mounted) {
        displayInfoBar(context, builder: (ctx, close) => InfoBar(
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
      final extraConfig = _extraConfigCtrl.text.trim();

      if (_isEditing) {
        await dao.updateConfig(AiProviderConfigsCompanion(
          id: Value(widget.existing!.id),
          name: Value(name),
          type: Value(_type),
          apiKey: Value(apiKey.isNotEmpty ? apiKey : null),
          baseUrl: Value(baseUrl.isNotEmpty ? baseUrl : null),
          defaultModel: Value(_defaultModel),
          isEnabled: Value(widget.existing!.isEnabled),
          extraConfig: Value(extraConfig.isNotEmpty ? extraConfig : null),
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
          extraConfig: Value(extraConfig.isNotEmpty ? extraConfig : null),
          createdAt: Value(now),
          updatedAt: Value(now),
        ));
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        displayInfoBar(context, builder: (ctx, close) => InfoBar(
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

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      title: Text(_isEditing ? '编辑服务商' : '添加服务商'),
      constraints: const BoxConstraints(maxWidth: 520),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoLabel(
              label: '服务商类型',
              child: ComboBox<String>(
                value: _type,
                items: _providerTypes
                    .map((t) => ComboBoxItem(value: t, child: Text(_typeLabel(t))))
                    .toList(),
                onChanged: _isEditing ? null : _onTypeChanged,
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 14),
            InfoLabel(
              label: '名称',
              child: TextBox(
                controller: _nameCtrl,
                placeholder: '输入显示名称',
              ),
            ),
            const SizedBox(height: 14),
            InfoLabel(
              label: 'API Key',
              child: PasswordBox(
                controller: _apiKeyCtrl,
                placeholder: '输入 API Key',
                revealMode: PasswordRevealMode.peekAlways,
              ),
            ),
            const SizedBox(height: 14),
            InfoLabel(
              label: 'API Base URL',
              child: TextBox(
                controller: _baseUrlCtrl,
                placeholder: '可选，自定义 API 端点',
              ),
            ),
            const SizedBox(height: 14),
            if (_currentModels.isNotEmpty) ...[
              InfoLabel(
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
              ),
              const SizedBox(height: 14),
            ],
            if (_type == 'custom')
              InfoLabel(
                label: '额外配置 (JSON)',
                child: TextBox(
                  controller: _extraConfigCtrl,
                  placeholder: '{"models":["model-1"],"chat_enabled":true}',
                  maxLines: 4,
                ),
              ),
            if (_type == 'custom') const SizedBox(height: 14),
            Row(
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
            ),
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
      return CustomService(
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
