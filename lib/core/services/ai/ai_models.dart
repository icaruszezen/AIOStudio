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

class AiImageRequest {
  final String prompt;
  final String? negativePrompt;
  final String model;
  final int width;
  final int height;
  final int count;
  final String? style;
  final String? quality;

  const AiImageRequest({
    required this.prompt,
    this.negativePrompt,
    required this.model,
    this.width = 1024,
    this.height = 1024,
    this.count = 1,
    this.style,
    this.quality,
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
      };
}

class AiGeneratedImage {
  final String? url;
  final String? base64;
  final String? revisedPrompt;

  const AiGeneratedImage({this.url, this.base64, this.revisedPrompt});

  factory AiGeneratedImage.fromJson(Map<String, dynamic> json) =>
      AiGeneratedImage(
        url: json['url'] as String?,
        base64: json['b64_json'] as String? ?? json['base64'] as String?,
        revisedPrompt: json['revised_prompt'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (url != null) 'url': url,
        if (base64 != null) 'b64_json': base64,
        if (revisedPrompt != null) 'revised_prompt': revisedPrompt,
      };
}

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

class AiVideoResponse {
  final String? videoUrl;
  final String? taskId;
  final String status;

  const AiVideoResponse({
    this.videoUrl,
    this.taskId,
    required this.status,
  });

  factory AiVideoResponse.fromJson(Map<String, dynamic> json) =>
      AiVideoResponse(
        videoUrl: json['video_url'] as String?,
        taskId: json['task_id'] as String?,
        status: json['status'] as String? ?? 'unknown',
      );

  Map<String, dynamic> toJson() => {
        if (videoUrl != null) 'video_url': videoUrl,
        if (taskId != null) 'task_id': taskId,
        'status': status,
      };
}
