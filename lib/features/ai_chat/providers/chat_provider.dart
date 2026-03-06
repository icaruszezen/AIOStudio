import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../core/services/ai/ai_service.dart';
import '../../../core/services/ai/ai_service_manager.dart';
import '../../../core/theme/app_theme.dart' show sharedPreferencesProvider;
import '../models/chat_models.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ChatState {
  final List<Conversation> conversations;
  final String? currentConversationId;
  final String? selectedProviderId;
  final String? selectedModel;
  final String systemPrompt;
  final bool isGenerating;

  const ChatState({
    this.conversations = const [],
    this.currentConversationId,
    this.selectedProviderId,
    this.selectedModel,
    this.systemPrompt = '',
    this.isGenerating = false,
  });

  Conversation? get currentConversation {
    if (currentConversationId == null) return null;
    return conversations
        .where((c) => c.id == currentConversationId)
        .firstOrNull;
  }

  ChatState copyWith({
    List<Conversation>? conversations,
    String? currentConversationId,
    String? selectedProviderId,
    String? selectedModel,
    String? systemPrompt,
    bool? isGenerating,
    bool clearCurrentConversation = false,
    bool clearModelSelection = false,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      currentConversationId: clearCurrentConversation
          ? null
          : (currentConversationId ?? this.currentConversationId),
      selectedProviderId: clearModelSelection
          ? null
          : (selectedProviderId ?? this.selectedProviderId),
      selectedModel: clearModelSelection
          ? null
          : (selectedModel ?? this.selectedModel),
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isGenerating: isGenerating ?? this.isGenerating,
    );
  }
}

// ---------------------------------------------------------------------------
// Notifier
// ---------------------------------------------------------------------------

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

class ChatNotifier extends Notifier<ChatState> {
  static final _log = Logger(printer: PrettyPrinter(methodCount: 0));
  static const _uuid = Uuid();
  static const _maxContextMessages = 50;
  static const _prefsLastModelKey = 'chat_last_model';

  StreamSubscription<String>? _activeSubscription;

  AiServiceManager get _serviceManager =>
      ref.read(aiServiceManagerProvider);

  @override
  ChatState build() {
    ref.onDispose(() {
      _activeSubscription?.cancel();
    });
    _initialize();
    return const ChatState();
  }

  Future<void> _initialize() async {
    await _restoreLastModel();
    await _loadFromDisk();
  }

  // ---------------------------------------------------------------------------
  // Model / Provider selection
  // ---------------------------------------------------------------------------

  List<ProviderModelGroup> getAvailableModelGroups() {
    final services = _serviceManager.getAllEnabledServices();
    return services
        .where((s) => s.supportsChatCompletion)
        .map((s) => ProviderModelGroup(
              providerId: s.providerId,
              providerName: s.providerName,
              models: s.supportedModels,
            ))
        .toList();
  }

  void selectModel(String providerId, String modelId) {
    state = state.copyWith(
      selectedProviderId: providerId,
      selectedModel: modelId,
    );
    _saveLastModel(providerId, modelId);
  }

  void setSystemPrompt(String prompt) {
    state = state.copyWith(systemPrompt: prompt);
    final conv = state.currentConversation;
    if (conv != null) {
      conv.systemPrompt = prompt;
      _notifyConversationsChanged();
    }
  }

  // ---------------------------------------------------------------------------
  // Conversation CRUD
  // ---------------------------------------------------------------------------

  String createConversation({String? title, String? model}) {
    final providerId = state.selectedProviderId ?? '';
    final modelId = model ?? state.selectedModel ?? '';
    final conv = Conversation(
      id: _uuid.v4(),
      title: title ?? '新对话',
      providerId: providerId,
      model: modelId,
      systemPrompt: state.systemPrompt.isNotEmpty ? state.systemPrompt : null,
    );
    final updated = [conv, ...state.conversations];
    state = state.copyWith(
      conversations: updated,
      currentConversationId: conv.id,
    );
    _saveToDisk();
    return conv.id;
  }

  void selectConversation(String id) {
    final conv = state.conversations.where((c) => c.id == id).firstOrNull;
    if (conv == null) return;
    final hasModel =
        conv.providerId.isNotEmpty && conv.model.isNotEmpty;
    state = state.copyWith(
      currentConversationId: id,
      selectedProviderId: hasModel ? conv.providerId : null,
      selectedModel: hasModel ? conv.model : null,
      clearModelSelection: !hasModel,
      systemPrompt: conv.systemPrompt ?? '',
    );
  }

  void renameConversation(String id, String title) {
    final conv = state.conversations.where((c) => c.id == id).firstOrNull;
    if (conv == null) return;
    conv
      ..title = title
      ..updatedAt = DateTime.now();
    _notifyConversationsChanged();
    _saveToDisk();
  }

  void deleteConversation(String id) {
    final updated = state.conversations.where((c) => c.id != id).toList();
    final isDeletingCurrent = state.currentConversationId == id;

    if (!isDeletingCurrent) {
      state = state.copyWith(conversations: updated);
    } else if (updated.isNotEmpty) {
      state = state.copyWith(
        conversations: updated,
        currentConversationId: updated.first.id,
      );
    } else {
      state = state.copyWith(
        conversations: updated,
        clearCurrentConversation: true,
      );
    }
    _saveToDisk();
  }

  void clearConversation(String id) {
    final conv = state.conversations.where((c) => c.id == id).firstOrNull;
    if (conv == null) return;
    conv
      ..messages.clear()
      ..updatedAt = DateTime.now();
    _notifyConversationsChanged();
    _saveToDisk();
  }

  // ---------------------------------------------------------------------------
  // Messaging
  // ---------------------------------------------------------------------------

  Future<void> sendMessage(String content, {List<String>? imageFiles}) async {
    if (content.trim().isEmpty && (imageFiles == null || imageFiles.isEmpty)) {
      return;
    }

    var conv = state.currentConversation;
    if (conv == null) {
      createConversation();
      conv = state.currentConversation!;
    }

    // Auto-title from first message
    if (conv.messages.isEmpty && content.trim().isNotEmpty) {
      final snippet = content.trim();
      conv.title =
          snippet.length > 30 ? '${snippet.substring(0, 30)}...' : snippet;
    }

    // Update conversation model to match current selection
    conv
      ..providerId = state.selectedProviderId ?? conv.providerId
      ..model = state.selectedModel ?? conv.model;

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'user',
      content: content,
      imagePaths: imageFiles,
    );
    conv.messages.add(userMsg);

    final assistantMsg = ChatMessage(
      id: _uuid.v4(),
      role: 'assistant',
      isStreaming: true,
    );
    conv
      ..messages.add(assistantMsg)
      ..updatedAt = DateTime.now();

    state = state.copyWith(isGenerating: true);
    _notifyConversationsChanged();

    final service = _getServiceForConversation(conv);
    if (service == null) {
      assistantMsg
        ..isStreaming = false
        ..error = '未找到可用的 AI 服务，请在设置中配置服务商';
      state = state.copyWith(isGenerating: false);
      _notifyConversationsChanged();
      return;
    }

    final request = _buildChatRequest(conv, service);
    final startedAt = DateTime.now();

    try {
      final stream = service.chatCompletionStream(request);
      _activeSubscription = stream.listen(
        (chunk) {
          assistantMsg.content += chunk;
          _notifyConversationsChanged();
        },
        onError: (Object error) {
          _log.e('[ChatNotifier] Stream error: $error');
          assistantMsg
            ..isStreaming = false
            ..error = _formatError(error);
          state = state.copyWith(isGenerating: false);
          _notifyConversationsChanged();
          _saveToDisk();
        },
        onDone: () {
          assistantMsg.isStreaming = false;
          state = state.copyWith(isGenerating: false);
          _notifyConversationsChanged();
          _recordAiTask(conv!, service, startedAt, assistantMsg);
          _saveToDisk();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _log.e('[ChatNotifier] Failed to start stream: $e');
      assistantMsg
        ..isStreaming = false
        ..error = _formatError(e);
      state = state.copyWith(isGenerating: false);
      _notifyConversationsChanged();
    }
  }

  void stopGeneration() {
    _activeSubscription?.cancel();
    _activeSubscription = null;

    final conv = state.currentConversation;
    if (conv != null && conv.messages.isNotEmpty) {
      final last = conv.messages.last;
      if (last.role == 'assistant' && last.isStreaming) {
        last.isStreaming = false;
        if (last.content.isEmpty) {
          last.error = '生成已中断';
        }
      }
    }
    state = state.copyWith(isGenerating: false);
    _notifyConversationsChanged();
    _saveToDisk();
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  AiService? _getServiceForConversation(Conversation conv) {
    if (conv.providerId.isNotEmpty) {
      final svc = _serviceManager.getService(conv.providerId);
      if (svc != null && svc.supportsChatCompletion) return svc;
    }
    return _serviceManager.getDefaultChatService();
  }

  AiChatRequest _buildChatRequest(Conversation conv, AiService service) {
    final messages = <AiChatMessage>[];

    final sysPrompt = conv.systemPrompt ?? state.systemPrompt;
    if (sysPrompt.isNotEmpty) {
      messages.add(AiChatMessage(
        role: 'system',
        content: sysPrompt,
        timestamp: conv.createdAt,
      ));
    }

    // Take only recent messages for context window safety
    final recent = conv.messages.length > _maxContextMessages
        ? conv.messages.sublist(conv.messages.length - _maxContextMessages)
        : conv.messages;

    for (final msg in recent) {
      if (msg.role == 'assistant' && msg.isStreaming) continue;
      if (msg.error != null && msg.content.isEmpty) continue;

      final imageUrls = msg.imagePaths
          ?.map((p) => 'file://$p')
          .toList();

      messages.add(AiChatMessage(
        role: msg.role,
        content: msg.content,
        imageUrls: imageUrls,
        timestamp: msg.timestamp,
      ));
    }

    final modelId = conv.model.isNotEmpty
        ? conv.model
        : (service.supportedModels.isNotEmpty
            ? service.supportedModels.first
            : 'default');

    return AiChatRequest(
      messages: messages,
      model: modelId,
      stream: true,
    );
  }

  void _notifyConversationsChanged() {
    state = state.copyWith(
      conversations: List.of(state.conversations),
    );
  }

  String _formatError(Object error) {
    final msg = error.toString();
    if (msg.contains('SocketException') || msg.contains('NetworkError')) {
      return '网络连接失败，请检查网络设置';
    }
    if (msg.contains('401') || msg.contains('AuthenticationError')) {
      return 'API 认证失败，请检查 API Key';
    }
    if (msg.contains('429') || msg.contains('RateLimitError')) {
      return '请求过于频繁，请稍后再试';
    }
    return '请求失败: $msg';
  }

  Future<void> _recordAiTask(
    Conversation conv,
    AiService service,
    DateTime startedAt,
    ChatMessage assistantMsg,
  ) async {
    try {
      final dao = ref.read(aiTaskDaoProvider);
      final now = DateTime.now();
      // Rough token estimate: ~4 chars per token for CJK-heavy text
      final estimatedTokens = (assistantMsg.content.length / 4).ceil();
      assistantMsg.completionTokens = estimatedTokens;

      await dao.insertTask(AiTasksCompanion(
        id: Value(_uuid.v4()),
        type: const Value('chat'),
        status: const Value('completed'),
        provider: Value(service.providerName),
        model: Value(conv.model),
        inputPrompt: Value(conv.messages
            .where((m) => m.role == 'user')
            .map((m) => m.content)
            .join('\n---\n')),
        outputText: Value(assistantMsg.content),
        tokenUsage: Value(estimatedTokens),
        startedAt: Value(startedAt.millisecondsSinceEpoch),
        completedAt: Value(now.millisecondsSinceEpoch),
        createdAt: Value(now.millisecondsSinceEpoch),
      ));
    } catch (e) {
      _log.w('[ChatNotifier] Failed to record AI task: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence (JSON files)
  // ---------------------------------------------------------------------------

  Future<Directory> _getChatDir() async {
    final appDir = await getApplicationSupportDirectory();
    final chatDir = Directory(p.join(appDir.path, 'chat_history'));
    if (!await chatDir.exists()) {
      await chatDir.create(recursive: true);
    }
    return chatDir;
  }

  Future<void> _saveToDisk() async {
    try {
      final dir = await _getChatDir();
      final indexFile = File(p.join(dir.path, 'conversations.json'));
      final data = state.conversations.map((c) => c.toJson()).toList();
      await indexFile.writeAsString(jsonEncode(data));
    } catch (e) {
      _log.w('[ChatNotifier] Failed to save conversations: $e');
    }
  }

  Future<void> _loadFromDisk() async {
    try {
      final dir = await _getChatDir();
      final indexFile = File(p.join(dir.path, 'conversations.json'));
      if (!await indexFile.exists()) return;

      final content = await indexFile.readAsString();
      final list = jsonDecode(content) as List<dynamic>;
      final convs = list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();

      for (final conv in convs) {
        _cleanUpStaleStreamingMessages(conv);
      }

      if (convs.isNotEmpty) {
        final first = convs.first;
        final hasModel =
            first.providerId.isNotEmpty && first.model.isNotEmpty;
        state = state.copyWith(
          conversations: convs,
          currentConversationId: first.id,
          selectedProviderId: hasModel ? first.providerId : null,
          selectedModel: hasModel ? first.model : null,
          systemPrompt: first.systemPrompt ?? '',
        );
      }
    } catch (e) {
      _log.w('[ChatNotifier] Failed to load conversations: $e');
    }
  }

  void _cleanUpStaleStreamingMessages(Conversation conv) {
    for (final msg in conv.messages) {
      if (msg.isStreaming) {
        msg.isStreaming = false;
        if (msg.content.isEmpty) {
          msg.error = '生成被中断（应用重启）';
        }
      }
    }
  }

  Future<void> _restoreLastModel() async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final key = prefs.getString(_prefsLastModelKey);
      if (key != null && key.contains('::')) {
        final parts = key.split('::');
        state = state.copyWith(
          selectedProviderId: parts[0],
          selectedModel: parts[1],
        );
      }
    } catch (_) {}
  }

  Future<void> _saveLastModel(String providerId, String modelId) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_prefsLastModelKey, '$providerId::$modelId');
    } catch (_) {}
  }
}
