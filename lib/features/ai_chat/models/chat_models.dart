import 'dart:convert';

// ---------------------------------------------------------------------------
// ChatRole enum
// ---------------------------------------------------------------------------

enum ChatRole {
  user,
  assistant,
  system;

  String toJson() => name;

  static ChatRole fromJson(String value) => ChatRole.values.firstWhere(
        (e) => e.name == value,
        orElse: () => ChatRole.user,
      );
}

// ---------------------------------------------------------------------------
// ChatMessage (immutable)
// ---------------------------------------------------------------------------

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final List<String>? imagePaths;
  final int? promptTokens;
  final int? completionTokens;
  final DateTime timestamp;
  final bool isStreaming;
  final String? error;

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

  ChatMessage copyWith({
    String? content,
    List<String>? imagePaths,
    int? promptTokens,
    int? completionTokens,
    DateTime? timestamp,
    bool? isStreaming,
    String? error,
    bool clearError = false,
  }) {
    return ChatMessage(
      id: id,
      role: role,
      content: content ?? this.content,
      imagePaths: imagePaths ?? this.imagePaths,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      timestamp: timestamp ?? this.timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatMessage &&
          other.id == id &&
          other.content == content &&
          other.isStreaming == isStreaming &&
          other.error == error &&
          other.completionTokens == completionTokens;

  @override
  int get hashCode =>
      Object.hash(id, content, isStreaming, error, completionTokens);

  Map<String, dynamic> toJson() => {
        'id': id,
        'role': role.toJson(),
        'content': content,
        if (imagePaths != null) 'imagePaths': imagePaths,
        if (promptTokens != null) 'promptTokens': promptTokens,
        if (completionTokens != null) 'completionTokens': completionTokens,
        'timestamp': timestamp.toIso8601String(),
        if (error != null) 'error': error,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        role: ChatRole.fromJson(json['role'] as String? ?? 'user'),
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

// ---------------------------------------------------------------------------
// Conversation (immutable)
// ---------------------------------------------------------------------------

class Conversation {
  final String id;
  final String title;
  final String providerId;
  final String model;
  final String? systemPrompt;
  final List<ChatMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    required this.providerId,
    required this.model,
    this.systemPrompt,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : messages = messages ?? const [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  Conversation copyWith({
    String? title,
    String? providerId,
    String? model,
    String? systemPrompt,
    bool clearSystemPrompt = false,
    List<ChatMessage>? messages,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      providerId: providerId ?? this.providerId,
      model: model ?? this.model,
      systemPrompt:
          clearSystemPrompt ? null : (systemPrompt ?? this.systemPrompt),
      messages: messages ?? this.messages,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Conversation &&
          other.id == id &&
          other.title == title &&
          other.updatedAt == updatedAt &&
          other.messages.length == messages.length;

  @override
  int get hashCode => Object.hash(id, title, updatedAt, messages.length);

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

// ---------------------------------------------------------------------------
// Model selector helpers (already immutable)
// ---------------------------------------------------------------------------

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
    final sep = key.indexOf('::');
    if (sep < 0) {
      return SelectedModel(
        providerId: key,
        providerName: providerName,
        modelId: '',
      );
    }
    return SelectedModel(
      providerId: key.substring(0, sep),
      providerName: providerName,
      modelId: key.substring(sep + 2),
    );
  }
}
