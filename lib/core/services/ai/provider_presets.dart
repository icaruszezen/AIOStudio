import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';

enum ProviderCategory {
  popular('主流服务商'),
  chinese('国内服务商'),
  local('本地部署'),
  custom('自定义');

  const ProviderCategory(this.label);
  final String label;
}

class ProviderPreset {
  final String id;
  final String name;
  final String description;
  final String serviceType;
  final IconData icon;
  final Color darkColor;
  final Color lightColor;
  final String defaultBaseUrl;
  final bool requiresApiKey;
  final bool supportsModelDiscovery;
  final List<String> defaultModels;
  final List<String> tags;
  final ProviderCategory category;

  const ProviderPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.serviceType,
    required this.icon,
    required this.darkColor,
    required this.lightColor,
    required this.defaultBaseUrl,
    this.requiresApiKey = true,
    this.supportsModelDiscovery = false,
    this.defaultModels = const [],
    this.tags = const [],
    required this.category,
  });

  Color color(Brightness b) => b == Brightness.dark ? darkColor : lightColor;
}

class ProviderPresets {
  ProviderPresets._();

  static const openai = ProviderPreset(
    id: 'openai',
    name: 'OpenAI',
    description: 'GPT-4o, DALL-E 等',
    serviceType: 'openai',
    icon: FluentIcons.chat_bot,
    darkColor: Color(0xFF34D399),
    lightColor: Color(0xFF10B981),
    defaultBaseUrl: 'https://api.openai.com',
    supportsModelDiscovery: true,
    defaultModels: [
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
    tags: ['chat', 'image'],
    category: ProviderCategory.popular,
  );

  static const anthropic = ProviderPreset(
    id: 'anthropic',
    name: 'Anthropic',
    description: 'Claude 4, Claude 3.5 等',
    serviceType: 'anthropic',
    icon: FluentIcons.robot,
    darkColor: Color(0xFFFBBF24),
    lightColor: Color(0xFFF59E0B),
    defaultBaseUrl: 'https://api.anthropic.com',
    defaultModels: [
      'claude-sonnet-4-20250514',
      'claude-4-opus-20250514',
      'claude-3-7-sonnet-20250219',
      'claude-3-5-sonnet-20241022',
      'claude-3-haiku-20240307',
      'claude-3-opus-20240229',
    ],
    tags: ['chat'],
    category: ProviderCategory.popular,
  );

  static const google = ProviderPreset(
    id: 'google',
    name: 'Google Gemini',
    description: 'Gemini 2.5, Gemini 2.0 等',
    serviceType: 'custom',
    icon: FluentIcons.cloud,
    darkColor: Color(0xFF60A5FA),
    lightColor: Color(0xFF3B82F6),
    defaultBaseUrl: 'https://generativelanguage.googleapis.com/v1beta/openai',
    supportsModelDiscovery: true,
    defaultModels: [
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-2.0-flash-lite',
    ],
    tags: ['chat', 'image'],
    category: ProviderCategory.popular,
  );

  static const groq = ProviderPreset(
    id: 'groq',
    name: 'Groq',
    description: '超快推理, Llama, Mixtral 等',
    serviceType: 'custom',
    icon: FluentIcons.auto_enhance_on,
    darkColor: Color(0xFFF97316),
    lightColor: Color(0xFFEA580C),
    defaultBaseUrl: 'https://api.groq.com/openai',
    supportsModelDiscovery: true,
    tags: ['chat'],
    category: ProviderCategory.popular,
  );

  static const openRouter = ProviderPreset(
    id: 'openrouter',
    name: 'OpenRouter',
    description: '聚合多家模型的统一接口',
    serviceType: 'custom',
    icon: FluentIcons.global_nav_button,
    darkColor: Color(0xFFFB7185),
    lightColor: Color(0xFFF43F5E),
    defaultBaseUrl: 'https://openrouter.ai/api',
    supportsModelDiscovery: true,
    tags: ['chat', 'image'],
    category: ProviderCategory.popular,
  );

  static const stability = ProviderPreset(
    id: 'stability',
    name: 'Stability AI',
    description: 'Stable Diffusion 图片生成',
    serviceType: 'stability',
    icon: FluentIcons.picture,
    darkColor: Color(0xFFA78BFA),
    lightColor: Color(0xFF8B5CF6),
    defaultBaseUrl: 'https://api.stability.ai',
    defaultModels: [
      'stable-diffusion-xl-1024-v1-0',
      'stable-diffusion-v1-6',
      'stable-image-ultra',
      'stable-image-core',
    ],
    tags: ['image'],
    category: ProviderCategory.popular,
  );

  static const deepseek = ProviderPreset(
    id: 'deepseek',
    name: 'DeepSeek',
    description: 'DeepSeek-V3, DeepSeek-R1 等',
    serviceType: 'custom',
    icon: FluentIcons.search,
    darkColor: Color(0xFF38BDF8),
    lightColor: Color(0xFF0EA5E9),
    defaultBaseUrl: 'https://api.deepseek.com',
    supportsModelDiscovery: true,
    defaultModels: ['deepseek-chat', 'deepseek-reasoner'],
    tags: ['chat'],
    category: ProviderCategory.chinese,
  );

  static const moonshot = ProviderPreset(
    id: 'moonshot',
    name: 'Moonshot / Kimi',
    description: '长上下文对话模型',
    serviceType: 'custom',
    icon: FluentIcons.chat,
    darkColor: Color(0xFF818CF8),
    lightColor: Color(0xFF6366F1),
    defaultBaseUrl: 'https://api.moonshot.cn',
    supportsModelDiscovery: true,
    defaultModels: ['moonshot-v1-128k', 'moonshot-v1-32k', 'moonshot-v1-8k'],
    tags: ['chat'],
    category: ProviderCategory.chinese,
  );

  static const siliconFlow = ProviderPreset(
    id: 'siliconflow',
    name: 'Silicon Flow',
    description: '高性能推理平台',
    serviceType: 'custom',
    icon: FluentIcons.sync,
    darkColor: Color(0xFF2DD4BF),
    lightColor: Color(0xFF14B8A6),
    defaultBaseUrl: 'https://api.siliconflow.cn',
    supportsModelDiscovery: true,
    tags: ['chat', 'image'],
    category: ProviderCategory.chinese,
  );

  static const ollama = ProviderPreset(
    id: 'ollama',
    name: 'Ollama',
    description: '本地运行开源模型',
    serviceType: 'custom',
    icon: FluentIcons.task_list,
    darkColor: Color(0xFF9CA3AF),
    lightColor: Color(0xFF6B7280),
    defaultBaseUrl: 'http://localhost:11434',
    requiresApiKey: false,
    supportsModelDiscovery: true,
    tags: ['chat'],
    category: ProviderCategory.local,
  );

  static const custom = ProviderPreset(
    id: 'custom',
    name: '自定义 (OpenAI 兼容)',
    description: '连接任何 OpenAI 兼容 API',
    serviceType: 'custom',
    icon: FluentIcons.settings,
    darkColor: Color(0xFFA78BFA),
    lightColor: Color(0xFF8B5CF6),
    defaultBaseUrl: '',
    requiresApiKey: false,
    supportsModelDiscovery: true,
    tags: ['chat', 'image'],
    category: ProviderCategory.custom,
  );

  static final List<ProviderPreset> all = List.unmodifiable([
    openai,
    anthropic,
    google,
    groq,
    openRouter,
    stability,
    deepseek,
    moonshot,
    siliconFlow,
    ollama,
    custom,
  ]);

  static ProviderPreset? getById(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }

  static List<ProviderPreset> getByCategory(ProviderCategory category) =>
      all.where((p) => p.category == category).toList();

  static List<ProviderPreset> search(String query) {
    final q = query.toLowerCase();
    return all
        .where(
          (p) =>
              p.name.toLowerCase().contains(q) ||
              p.description.toLowerCase().contains(q) ||
              p.id.toLowerCase().contains(q),
        )
        .toList();
  }

  static String? storedPresetId(String? extraConfigJson) {
    if (extraConfigJson == null) return null;
    try {
      final extra = jsonDecode(extraConfigJson) as Map<String, dynamic>;
      final preset = extra['preset'] as String?;
      if (preset != null && getById(preset) != null) return preset;
    } catch (_) {}
    return null;
  }

  /// Resolve the preset id for an existing provider config.
  /// Checks extraConfig['preset'] first, then falls back to heuristics.
  static String resolvePresetId(
    String type,
    String? baseUrl,
    String? extraConfigJson,
  ) {
    final storedPreset = storedPresetId(extraConfigJson);
    if (storedPreset != null) return storedPreset;

    if (type == 'openai') return 'openai';
    if (type == 'anthropic') return 'anthropic';
    if (type == 'stability') return 'stability';

    if (baseUrl != null) {
      final url = baseUrl.toLowerCase();
      if (url.contains('deepseek')) return 'deepseek';
      if (url.contains('groq')) return 'groq';
      if (url.contains('moonshot')) return 'moonshot';
      if (url.contains('siliconflow')) return 'siliconflow';
      if (url.contains('openrouter')) return 'openrouter';
      if (url.contains('googleapis.com')) return 'google';
      if (_looksLikeOllamaBaseUrl(url)) {
        return 'ollama';
      }
    }

    return 'custom';
  }

  static bool _looksLikeOllamaBaseUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();
    final isLocalHost =
        host == 'localhost' || host == '127.0.0.1' || host == '::1';
    return isLocalHost && uri.port == 11434;
  }
}
