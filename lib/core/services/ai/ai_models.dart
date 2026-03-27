import 'dart:convert';
import 'dart:typed_data';

/// Metadata and feature flags for one model id exposed by a provider.
class AiModelInfo {
  final String id;
  final int? contextWindow;
  final int? maxOutputTokens;
  final String mode;
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
  final bool isEnabled;

  const AiModelInfo({
    required this.id,
    this.contextWindow,
    this.maxOutputTokens,
    this.mode = 'chat',
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
    this.isEnabled = true,
  });

  /// Equality is based solely on [id] because model identifiers are unique
  /// within a provider. Other fields (contextWindow, mode, isEnabled, etc.)
  /// are intentionally excluded so that enriched and bare instances of the
  /// same model compare as equal.
  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is AiModelInfo && other.id == id;

  @override
  int get hashCode => id.hashCode;

  bool get isChatModel => mode == 'chat' || mode == 'responses';
  bool get isImageModel =>
      mode == 'image_generation' || outputModalities.contains('image');
  bool get isVideoModel => mode == 'video_generation';
  bool get isEmbeddingModel => mode == 'embedding';
  bool get isAudioModel =>
      mode == 'audio_transcription' || mode == 'audio_speech';

  String get contextWindowLabel {
    if (contextWindow == null) return '';
    if (contextWindow! >= 1000000) {
      return '${(contextWindow! / 1000000).toStringAsFixed(contextWindow! % 1000000 == 0 ? 0 : 1)}M';
    }
    return '${(contextWindow! / 1000).toStringAsFixed(0)}K';
  }

  AiModelInfo copyWith({
    String? id,
    int? contextWindow,
    int? maxOutputTokens,
    String? mode,
    List<String>? inputModalities,
    List<String>? outputModalities,
    bool? supportsVision,
    bool? supportsFunctionCalling,
    bool? supportsReasoning,
    bool? supportsResponseSchema,
    bool? supportsWebSearch,
    bool? supportsAudioInput,
    bool? supportsAudioOutput,
    bool? supportsParallelFunctionCalling,
    bool? supportsPromptCaching,
    bool? supportsSystemMessages,
    bool? isEnabled,
  }) {
    return AiModelInfo(
      id: id ?? this.id,
      contextWindow: contextWindow ?? this.contextWindow,
      maxOutputTokens: maxOutputTokens ?? this.maxOutputTokens,
      mode: mode ?? this.mode,
      inputModalities: inputModalities ?? this.inputModalities,
      outputModalities: outputModalities ?? this.outputModalities,
      supportsVision: supportsVision ?? this.supportsVision,
      supportsFunctionCalling:
          supportsFunctionCalling ?? this.supportsFunctionCalling,
      supportsReasoning: supportsReasoning ?? this.supportsReasoning,
      supportsResponseSchema:
          supportsResponseSchema ?? this.supportsResponseSchema,
      supportsWebSearch: supportsWebSearch ?? this.supportsWebSearch,
      supportsAudioInput: supportsAudioInput ?? this.supportsAudioInput,
      supportsAudioOutput: supportsAudioOutput ?? this.supportsAudioOutput,
      supportsParallelFunctionCalling:
          supportsParallelFunctionCalling ??
          this.supportsParallelFunctionCalling,
      supportsPromptCaching:
          supportsPromptCaching ?? this.supportsPromptCaching,
      supportsSystemMessages:
          supportsSystemMessages ?? this.supportsSystemMessages,
      isEnabled: isEnabled ?? this.isEnabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (contextWindow != null) 'context_window': contextWindow,
    if (maxOutputTokens != null) 'max_output_tokens': maxOutputTokens,
    'mode': mode,
    'input_modalities': inputModalities,
    'output_modalities': outputModalities,
    'supports_vision': supportsVision,
    'supports_function_calling': supportsFunctionCalling,
    'supports_reasoning': supportsReasoning,
    'supports_response_schema': supportsResponseSchema,
    'supports_web_search': supportsWebSearch,
    'supports_audio_input': supportsAudioInput,
    'supports_audio_output': supportsAudioOutput,
    'supports_parallel_function_calling': supportsParallelFunctionCalling,
    'supports_prompt_caching': supportsPromptCaching,
    'supports_system_messages': supportsSystemMessages,
    'is_enabled': isEnabled,
  };

  factory AiModelInfo.fromJson(Map<String, dynamic> json) => AiModelInfo(
    id: json['id'] as String,
    contextWindow: json['context_window'] as int?,
    maxOutputTokens: json['max_output_tokens'] as int?,
    mode: json['mode'] as String? ?? 'chat',
    inputModalities:
        (json['input_modalities'] as List<dynamic>?)?.cast<String>() ??
        const ['text'],
    outputModalities:
        (json['output_modalities'] as List<dynamic>?)?.cast<String>() ??
        const ['text'],
    supportsVision: json['supports_vision'] as bool? ?? false,
    supportsFunctionCalling:
        json['supports_function_calling'] as bool? ?? false,
    supportsReasoning: json['supports_reasoning'] as bool? ?? false,
    supportsResponseSchema: json['supports_response_schema'] as bool? ?? false,
    supportsWebSearch: json['supports_web_search'] as bool? ?? false,
    supportsAudioInput: json['supports_audio_input'] as bool? ?? false,
    supportsAudioOutput: json['supports_audio_output'] as bool? ?? false,
    supportsParallelFunctionCalling:
        json['supports_parallel_function_calling'] as bool? ?? false,
    supportsPromptCaching: json['supports_prompt_caching'] as bool? ?? false,
    supportsSystemMessages: json['supports_system_messages'] as bool? ?? false,
    isEnabled: json['is_enabled'] as bool? ?? true,
  );

  /// Create from registry capability data (without an explicit id in the map).
  factory AiModelInfo.fromCapability(String modelId, Map<String, dynamic> cap) {
    return AiModelInfo(
      id: modelId,
      contextWindow: cap['max_input_tokens'] as int?,
      maxOutputTokens: cap['max_output_tokens'] as int?,
      mode: cap['mode'] as String? ?? 'chat',
      inputModalities:
          (cap['supported_modalities'] as List<dynamic>?)?.cast<String>() ??
          const ['text'],
      outputModalities:
          (cap['supported_output_modalities'] as List<dynamic>?)
              ?.cast<String>() ??
          const ['text'],
      supportsVision: cap['supports_vision'] as bool? ?? false,
      supportsFunctionCalling:
          cap['supports_function_calling'] as bool? ?? false,
      supportsReasoning: cap['supports_reasoning'] as bool? ?? false,
      supportsResponseSchema: cap['supports_response_schema'] as bool? ?? false,
      supportsWebSearch: cap['supports_web_search'] as bool? ?? false,
      supportsAudioInput: cap['supports_audio_input'] as bool? ?? false,
      supportsAudioOutput: cap['supports_audio_output'] as bool? ?? false,
      supportsParallelFunctionCalling:
          cap['supports_parallel_function_calling'] as bool? ?? false,
      supportsPromptCaching: cap['supports_prompt_caching'] as bool? ?? false,
      supportsSystemMessages: cap['supports_system_messages'] as bool? ?? false,
    );
  }
}

/// A single turn in a chat: role, text content, optional image URLs, and time.
class AiChatMessage {
  final String role;
  final String content;
  final List<String>? imageUrls;
  final DateTime timestamp;

  const AiChatMessage({
    required this.role,
    required this.content,
    this.imageUrls,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'role': role,
    'content': content,
    if (imageUrls != null) 'image_urls': imageUrls,
    'timestamp': timestamp.toIso8601String(),
  };

  factory AiChatMessage.fromJson(Map<String, dynamic> json) => AiChatMessage(
    role: json['role'] as String,
    content: json['content'] as String,
    imageUrls: (json['image_urls'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList(),
    timestamp: json['timestamp'] != null
        ? DateTime.parse(json['timestamp'] as String)
        : DateTime.now(),
  );
}

/// Request payload for chat completion: messages, model, sampling, and stream flag.
class AiChatRequest {
  final List<AiChatMessage> messages;
  final String model;
  final double temperature;
  final int? maxTokens;
  final bool stream;

  const AiChatRequest({
    required this.messages,
    required this.model,
    this.temperature = 0.7,
    this.maxTokens,
    this.stream = true,
  });

  Map<String, dynamic> toJson() => {
    'messages': messages.map((m) => m.toJson()).toList(),
    'model': model,
    'temperature': temperature,
    if (maxTokens != null) 'max_tokens': maxTokens,
    'stream': stream,
  };
}

/// Assistant reply plus token usage from a completed chat call.
class AiChatResponse {
  final String content;
  final String model;
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const AiChatResponse({
    required this.content,
    required this.model,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
  });

  factory AiChatResponse.fromJson(Map<String, dynamic> json) {
    final usage = json['usage'] as Map<String, dynamic>? ?? {};
    return AiChatResponse(
      content: json['content'] as String? ?? '',
      model: json['model'] as String? ?? '',
      promptTokens: usage['prompt_tokens'] as int? ?? 0,
      completionTokens: usage['completion_tokens'] as int? ?? 0,
      totalTokens: usage['total_tokens'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'content': content,
    'model': model,
    'usage': {
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'total_tokens': totalTokens,
    },
  };
}

/// Image generation input: prompt, model, size, count, and optional tuning fields.
class AiImageRequest {
  final String prompt;
  final String? negativePrompt;
  final String model;
  final int width;
  final int height;
  final int count;
  final String? style;
  final String? quality;
  final double? cfgScale;
  final int? steps;
  final int? seed;

  const AiImageRequest({
    required this.prompt,
    this.negativePrompt,
    required this.model,
    this.width = 1024,
    this.height = 1024,
    this.count = 1,
    this.style,
    this.quality,
    this.cfgScale,
    this.steps,
    this.seed,
  });

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    if (negativePrompt != null) 'negative_prompt': negativePrompt,
    'model': model,
    'width': width,
    'height': height,
    'count': count,
    if (style != null) 'style': style,
    if (quality != null) 'quality': quality,
    if (cfgScale != null) 'cfg_scale': cfgScale,
    if (steps != null) 'steps': steps,
    if (seed != null) 'seed': seed,
  };
}

/// One generated image as a URL, base64 payload, and/or provider-revised prompt.
class AiGeneratedImage {
  final String? url;
  final String? base64;
  final String? revisedPrompt;

  Uint8List? _cachedBytes;

  AiGeneratedImage({this.url, this.base64, this.revisedPrompt});

  factory AiGeneratedImage.fromJson(Map<String, dynamic> json) =>
      AiGeneratedImage(
        url: json['url'] as String?,
        base64: json['b64_json'] as String? ?? json['base64'] as String?,
        revisedPrompt: json['revised_prompt'] as String?,
      );

  /// Lazily decoded bytes from [base64]. Safe to call repeatedly.
  Uint8List? get bytes {
    if (base64 == null) return null;
    return _cachedBytes ??= base64Decode(base64!);
  }

  Map<String, dynamic> toJson() => {
    if (url != null) 'url': url,
    if (base64 != null) 'b64_json': base64,
    if (revisedPrompt != null) 'revised_prompt': revisedPrompt,
  };
}

/// Batch result wrapping a list of [AiGeneratedImage] entries.
class AiImageResponse {
  final List<AiGeneratedImage> images;

  const AiImageResponse({required this.images});

  factory AiImageResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as List<dynamic>? ?? [];
    return AiImageResponse(
      images: data
          .map((e) => AiGeneratedImage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'data': images.map((i) => i.toJson()).toList(),
  };
}

/// Video generation input: prompt, model, dimensions, duration, optional image-to-video URL.
class AiVideoRequest {
  final String prompt;
  final String model;
  final int width;
  final int height;
  final int duration;
  final String? imageUrl;

  const AiVideoRequest({
    required this.prompt,
    required this.model,
    required this.width,
    required this.height,
    required this.duration,
    this.imageUrl,
  });

  Map<String, dynamic> toJson() => {
    'prompt': prompt,
    'model': model,
    'width': width,
    'height': height,
    'duration': duration,
    if (imageUrl != null) 'image_url': imageUrl,
  };
}

/// Video job outcome: playable URL, async task id, status, and optional error text.
class AiVideoResponse {
  final String? videoUrl;
  final String? taskId;
  final String status;
  final String? errorMessage;

  const AiVideoResponse({
    this.videoUrl,
    this.taskId,
    required this.status,
    this.errorMessage,
  });

  factory AiVideoResponse.fromJson(Map<String, dynamic> json) =>
      AiVideoResponse(
        videoUrl: json['video_url'] as String?,
        taskId: json['task_id'] as String?,
        status: json['status'] as String? ?? 'unknown',
        errorMessage:
            json['error_message'] as String? ?? json['error'] as String?,
      );

  Map<String, dynamic> toJson() => {
    if (videoUrl != null) 'video_url': videoUrl,
    if (taskId != null) 'task_id': taskId,
    'status': status,
    if (errorMessage != null) 'error_message': errorMessage,
  };
}
