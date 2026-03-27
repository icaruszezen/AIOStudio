import 'package:fluent_ui/fluent_ui.dart';

import 'ai_models.dart';

class ModelCapabilityPreset {
  final String id;
  final String name;
  final String description;
  final IconData icon;

  final String mode;
  final int? contextWindow;
  final int? maxOutputTokens;
  final List<String> inputModalities;
  final List<String> outputModalities;
  final bool supportsVision;
  final bool supportsFunctionCalling;
  final bool supportsReasoning;
  final bool supportsResponseSchema;
  final bool supportsWebSearch;
  final bool supportsAudioInput;
  final bool supportsAudioOutput;
  final bool supportsParallelFunctionCalling;
  final bool supportsPromptCaching;
  final bool supportsSystemMessages;

  const ModelCapabilityPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    this.mode = 'chat',
    this.contextWindow,
    this.maxOutputTokens,
    this.inputModalities = const ['text'],
    this.outputModalities = const ['text'],
    this.supportsVision = false,
    this.supportsFunctionCalling = false,
    this.supportsReasoning = false,
    this.supportsResponseSchema = false,
    this.supportsWebSearch = false,
    this.supportsAudioInput = false,
    this.supportsAudioOutput = false,
    this.supportsParallelFunctionCalling = false,
    this.supportsPromptCaching = false,
    this.supportsSystemMessages = false,
  });

  AiModelInfo apply(String modelId, {bool isEnabled = true}) => AiModelInfo(
    id: modelId,
    contextWindow: contextWindow,
    maxOutputTokens: maxOutputTokens,
    mode: mode,
    inputModalities: inputModalities,
    outputModalities: outputModalities,
    supportsVision: supportsVision,
    supportsFunctionCalling: supportsFunctionCalling,
    supportsReasoning: supportsReasoning,
    supportsResponseSchema: supportsResponseSchema,
    supportsWebSearch: supportsWebSearch,
    supportsAudioInput: supportsAudioInput,
    supportsAudioOutput: supportsAudioOutput,
    supportsParallelFunctionCalling: supportsParallelFunctionCalling,
    supportsPromptCaching: supportsPromptCaching,
    supportsSystemMessages: supportsSystemMessages,
    isEnabled: isEnabled,
  );
}

class ModelCapabilityPresets {
  ModelCapabilityPresets._();

  static const flagship = ModelCapabilityPreset(
    id: 'flagship',
    name: '旗舰对话',
    description: 'GPT-4o / Claude 4 级别',
    icon: FluentIcons.chat_bot,
    contextWindow: 128000,
    maxOutputTokens: 16384,
    inputModalities: ['text', 'image'],
    supportsVision: true,
    supportsFunctionCalling: true,
    supportsReasoning: true,
    supportsResponseSchema: true,
    supportsWebSearch: true,
    supportsParallelFunctionCalling: true,
    supportsPromptCaching: true,
    supportsSystemMessages: true,
  );

  static const standard = ModelCapabilityPreset(
    id: 'standard',
    name: '标准对话',
    description: 'GPT-4o-mini / Claude Haiku 级别',
    icon: FluentIcons.chat,
    contextWindow: 128000,
    maxOutputTokens: 16384,
    supportsVision: true,
    supportsFunctionCalling: true,
    supportsResponseSchema: true,
    supportsParallelFunctionCalling: true,
    supportsSystemMessages: true,
  );

  static const reasoning = ModelCapabilityPreset(
    id: 'reasoning',
    name: '推理模型',
    description: 'o1 / DeepSeek-R1 / QwQ 级别',
    icon: FluentIcons.lightbulb,
    contextWindow: 128000,
    maxOutputTokens: 65536,
    supportsReasoning: true,
    supportsSystemMessages: true,
  );

  static const longContext = ModelCapabilityPreset(
    id: 'long_context',
    name: '长上下文',
    description: 'Gemini 2.5 / Kimi 级别',
    icon: FluentIcons.document_set,
    contextWindow: 1000000,
    maxOutputTokens: 65536,
    inputModalities: ['text', 'image'],
    supportsVision: true,
    supportsFunctionCalling: true,
    supportsResponseSchema: true,
    supportsPromptCaching: true,
    supportsSystemMessages: true,
  );

  static const multimodal = ModelCapabilityPreset(
    id: 'multimodal',
    name: '多模态',
    description: 'GPT-4o-audio / Gemini 级别',
    icon: FluentIcons.picture,
    contextWindow: 128000,
    maxOutputTokens: 16384,
    inputModalities: ['text', 'image', 'audio'],
    outputModalities: ['text', 'audio'],
    supportsVision: true,
    supportsAudioInput: true,
    supportsAudioOutput: true,
    supportsFunctionCalling: true,
    supportsSystemMessages: true,
  );

  static const imageGeneration = ModelCapabilityPreset(
    id: 'image_gen',
    name: '图片生成',
    description: 'DALL-E / Stable Diffusion 级别',
    icon: FluentIcons.photo2,
    mode: 'image_generation',
    inputModalities: ['text'],
    outputModalities: ['image'],
  );

  static const embedding = ModelCapabilityPreset(
    id: 'embedding',
    name: '嵌入模型',
    description: 'text-embedding 级别',
    icon: FluentIcons.number_field,
    mode: 'embedding',
    contextWindow: 8192,
  );

  static const audio = ModelCapabilityPreset(
    id: 'audio',
    name: '语音模型',
    description: 'Whisper / TTS 级别',
    icon: FluentIcons.microphone,
    mode: 'audio_speech',
    supportsAudioInput: true,
    supportsAudioOutput: true,
    inputModalities: ['text', 'audio'],
    outputModalities: ['audio'],
  );

  static const List<ModelCapabilityPreset> all = [
    flagship,
    standard,
    reasoning,
    longContext,
    multimodal,
    imageGeneration,
    embedding,
    audio,
  ];

  static ModelCapabilityPreset? getById(String id) {
    for (final p in all) {
      if (p.id == id) return p;
    }
    return null;
  }
}
