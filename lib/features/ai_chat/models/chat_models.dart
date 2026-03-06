import 'dart:convert';

class Conversation {
  final String id;
  String title;
  String providerId;
  String model;
  String? systemPrompt;
  List<ChatMessage> messages;
  DateTime createdAt;
  DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    required this.providerId,
    required this.model,
    this.systemPrompt,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'providerId': providerId,
        'model': model,
        if (systemPrompt != null) 'systemPrompt': systemPrompt,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        title: json['title'] as String,
        providerId: json['providerId'] as String,
        model: json['model'] as String,
        systemPrompt: json['systemPrompt'] as String?,
        messages: (json['messages'] as List<dynamic>?)
                ?.map(
                    (e) => ChatMessage.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());

  factory Conversation.fromJsonString(String jsonStr) =>
      Conversation.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}

class ChatMessage {
  final String id;
  final String role;
  String content;
  List<String>? imagePaths;
  int? promptTokens;
  int? completionTokens;
  DateTime timestamp;
  bool isStreaming;
  String? error;

  ChatMessage({
    required this.id,
    required this.role,
    this.content = '',
    this.imagePaths,
    this.promptTokens,
    this.completionTokens,
    DateTime? timestamp,
    this.isStreaming = false,
    this.error,
  }) : timestamp = timestamp ?? DateTime.now();

  int? get totalTokens {
    if (promptTokens == null && completionTokens == null) return null;
    return (promptTokens ?? 0) + (completionTokens ?? 0);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role,
        'content': content,
        if (imagePaths != null) 'imagePaths': imagePaths,
        if (promptTokens != null) 'promptTokens': promptTokens,
        if (completionTokens != null) 'completionTokens': completionTokens,
        'timestamp': timestamp.toIso8601String(),
        if (error != null) 'error': error,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: json['role'] as String,
        content: json['content'] as String? ?? '',
        imagePaths: (json['imagePaths'] as List<dynamic>?)
            ?.map((e) => e as String)
            .toList(),
        promptTokens: json['promptTokens'] as int?,
        completionTokens: json['completionTokens'] as int?,
        timestamp: json['timestamp'] != null
            ? DateTime.parse(json['timestamp'] as String)
            : DateTime.now(),
        error: json['error'] as String?,
      );
}

/// Grouped model entry for the model selector UI.
class ProviderModelGroup {
  final String providerId;
  final String providerName;
  final List<String> models;

  const ProviderModelGroup({
    required this.providerId,
    required this.providerName,
    required this.models,
  });
}

/// Identifies a specific model from a specific provider.
class SelectedModel {
  final String providerId;
  final String providerName;
  final String modelId;

  const SelectedModel({
    required this.providerId,
    required this.providerName,
    required this.modelId,
  });

  String get displayName => '$providerName / $modelId';

  String get storageKey => '$providerId::$modelId';

  factory SelectedModel.fromStorageKey(
    String key,
    String providerName,
  ) {
    final parts = key.split('::');
    return SelectedModel(
      providerId: parts[0],
      providerName: providerName,
      modelId: parts.length > 1 ? parts[1] : '',
    );
  }
}
