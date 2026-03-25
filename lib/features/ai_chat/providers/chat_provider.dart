import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show compute;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:logger/logger.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/ai_providers.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/ai/ai_models.dart';
import '../../../shared/utils/error_utils.dart';
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
  static const _defaultMaxContextMessages = 50;
  static const _prefsLastModelKey = 'chat_last_model';
  static const _idleTimeoutDuration = Duration(seconds: 60);
  static const _jsonVersion = 1;

  StreamSubscription<String>? _activeSubscription;
  CancelToken? _activeCancelToken;
  Timer? _idleTimer;

  AiServiceManager get _serviceManager =>
      ref.read(aiServiceManagerProvider);

  @override
  ChatState build() {
    ref.onDispose(() {
      _activeSubscription?.cancel();
      _activeCancelToken?.cancel();
      _idleTimer?.cancel();
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
    final conv = state.currentConversation;
    if (conv != null) {
      state = state.copyWith(
        systemPrompt: prompt,
        conversations: state.conversations.map((c) {
          if (c.id != conv.id) return c;
          return prompt.isEmpty
              ? c.copyWith(clearSystemPrompt: true)
              : c.copyWith(systemPrompt: prompt);
        }).toList(),
      );
    } else {
      state = state.copyWith(systemPrompt: prompt);
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
    state = state.copyWith(
      conversations: [conv, ...state.conversations],
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
    state = state.copyWith(
      conversations: state.conversations.map((c) {
        if (c.id != id) return c;
        return c.copyWith(title: title, updatedAt: DateTime.now());
      }).toList(),
    );
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
    state = state.copyWith(
      conversations: state.conversations.map((c) {
        if (c.id != id) return c;
        return c.copyWith(messages: [], updatedAt: DateTime.now());
      }).toList(),
    );
    _saveToDisk();
  }

  // ---------------------------------------------------------------------------
  // Messaging
  // ---------------------------------------------------------------------------

  Future<void> sendMessage(String content, {List<String>? imageFiles}) async {
    if (state.isGenerating) return;
    if (content.trim().isEmpty && (imageFiles == null || imageFiles.isEmpty)) {
      return;
    }

    _activeSubscription?.cancel();
    _activeSubscription = null;
    _activeCancelToken?.cancel();
    _activeCancelToken = null;
    _idleTimer?.cancel();

    var conv = state.currentConversation;
    if (conv == null) {
      createConversation();
      conv = state.currentConversation!;
    }

    if (conv.messages.isEmpty && content.trim().isNotEmpty) {
      final snippet = content.trim();
      conv = conv.copyWith(
        title:
            snippet.length > 30 ? '${snippet.substring(0, 30)}...' : snippet,
      );
    }

    conv = conv.copyWith(
      providerId: state.selectedProviderId ?? conv.providerId,
      model: state.selectedModel ?? conv.model,
    );

    List<String>? persistedImages;
    if (imageFiles != null && imageFiles.isNotEmpty) {
      persistedImages = await _persistImages(imageFiles);
    }

    final userMsg = ChatMessage(
      id: _uuid.v4(),
      role: ChatRole.user,
      content: content,
      imagePaths: persistedImages,
    );
    final assistantMsgId = _uuid.v4();
    final assistantMsg = ChatMessage(
      id: assistantMsgId,
      role: ChatRole.assistant,
      isStreaming: true,
    );

    final convId = conv.id;
    conv = conv.copyWith(
      messages: [...conv.messages, userMsg, assistantMsg],
      updatedAt: DateTime.now(),
    );

    state = state.copyWith(
      conversations:
          state.conversations.map((c) => c.id == convId ? conv! : c).toList(),
      isGenerating: true,
    );

    final service = _getServiceForConversation(conv);
    if (service == null) {
      _updateMessage(convId, assistantMsgId, (msg) => msg.copyWith(
            isStreaming: false,
            error: '未找到可用的 AI 服务，请在设置中配置服务商',
          ));
      state = state.copyWith(isGenerating: false);
      return;
    }

    final request = await _buildChatRequest(conv, service);
    final startedAt = DateTime.now();

    try {
      _activeCancelToken = CancelToken();
      final stream = service.chatCompletionStream(
        request,
        cancelToken: _activeCancelToken,
      );
      _resetIdleTimer(convId, assistantMsgId);

      _activeSubscription = stream.listen(
        (chunk) {
          _resetIdleTimer(convId, assistantMsgId);
          _updateMessage(convId, assistantMsgId,
              (msg) => msg.copyWith(content: msg.content + chunk));
        },
        onError: (Object error) {
          _log.e('[ChatNotifier] Stream error: $error');
          _idleTimer?.cancel();
          _idleTimer = null;
          _activeSubscription = null;
          _updateMessage(convId, assistantMsgId, (msg) => msg.copyWith(
                isStreaming: false,
                error: formatUserError(error),
              ));
          state = state.copyWith(isGenerating: false);
          _saveToDisk();
        },
        onDone: () {
          _idleTimer?.cancel();
          _idleTimer = null;
          _activeSubscription = null;
          _updateMessage(convId, assistantMsgId,
              (msg) => msg.copyWith(isStreaming: false));
          state = state.copyWith(isGenerating: false);
          _recordAiTask(convId, assistantMsgId, service, startedAt);
          _saveToDisk();
        },
        cancelOnError: true,
      );
    } catch (e) {
      _log.e('[ChatNotifier] Failed to start stream: $e');
      _updateMessage(convId, assistantMsgId, (msg) => msg.copyWith(
            isStreaming: false,
            error: formatUserError(e),
          ));
      state = state.copyWith(isGenerating: false);
    }
  }

  void stopGeneration() {
    _activeSubscription?.cancel();
    _activeSubscription = null;
    _activeCancelToken?.cancel();
    _activeCancelToken = null;
    _idleTimer?.cancel();
    _idleTimer = null;

    final conv = state.currentConversation;
    if (conv != null && conv.messages.isNotEmpty) {
      final last = conv.messages.last;
      if (last.role == ChatRole.assistant && last.isStreaming) {
        _updateMessage(
          conv.id,
          last.id,
          (msg) => msg.copyWith(
            isStreaming: false,
            error: msg.content.isEmpty ? '生成已中断' : null,
          ),
        );
      }
    }
    state = state.copyWith(isGenerating: false);
    _saveToDisk();
  }

  // ---------------------------------------------------------------------------
  // Immutable state helpers
  // ---------------------------------------------------------------------------

  void _updateMessage(
    String convId,
    String msgId,
    ChatMessage Function(ChatMessage) updater,
  ) {
    state = state.copyWith(
      conversations: state.conversations.map((c) {
        if (c.id != convId) return c;
        return c.copyWith(
          messages:
              c.messages.map((m) => m.id == msgId ? updater(m) : m).toList(),
          updatedAt: DateTime.now(),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Idle timeout
  // ---------------------------------------------------------------------------

  void _resetIdleTimer(String convId, String msgId) {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeoutDuration, () {
      _log.w('[ChatNotifier] Stream idle timeout after '
          '${_idleTimeoutDuration.inSeconds}s');
      _activeSubscription?.cancel();
      _activeSubscription = null;
      _idleTimer = null;
      _updateMessage(convId, msgId, (msg) => msg.copyWith(
            isStreaming: false,
            error: '响应超时（${_idleTimeoutDuration.inSeconds}秒无数据），请重试',
          ));
      state = state.copyWith(isGenerating: false);
      _saveToDisk();
    });
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

  Future<AiChatRequest> _buildChatRequest(
      Conversation conv, AiService service) async {
    final messages = <AiChatMessage>[];

    final sysPrompt = conv.systemPrompt ?? state.systemPrompt;
    if (sysPrompt.isNotEmpty) {
      messages.add(AiChatMessage(
        role: ChatRole.system.toJson(),
        content: sysPrompt,
        timestamp: conv.createdAt,
      ));
    }

    final contextLimit = _computeContextLimit(service, conv.model);
    final recent = conv.messages.length > contextLimit
        ? conv.messages.sublist(conv.messages.length - contextLimit)
        : conv.messages;

    for (final msg in recent) {
      if (msg.role == ChatRole.assistant && msg.isStreaming) continue;
      if (msg.error != null && msg.content.isEmpty) continue;

      List<String>? imageUrls;
      if (msg.imagePaths != null && msg.imagePaths!.isNotEmpty) {
        imageUrls = [];
        for (final path in msg.imagePaths!) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            final b64 = base64Encode(bytes);
            final mime = _imageMimeType(path);
            imageUrls.add('data:$mime;base64,$b64');
          }
        }
        if (imageUrls.isEmpty) imageUrls = null;
      }

      messages.add(AiChatMessage(
        role: msg.role.toJson(),
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

  int _computeContextLimit(AiService service, String modelId) {
    final info =
        service.modelInfos.where((m) => m.id == modelId).firstOrNull;
    if (info?.contextWindow != null && info!.contextWindow! > 0) {
      final usableTokens = (info.contextWindow! * 0.75).toInt();
      return (usableTokens ~/ 50).clamp(10, 200);
    }
    return _defaultMaxContextMessages;
  }

  static String _imageMimeType(String path) {
    final ext = p.extension(path).toLowerCase();
    switch (ext) {
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.png':
        return 'image/png';
      case '.gif':
        return 'image/gif';
      case '.webp':
        return 'image/webp';
      case '.bmp':
        return 'image/bmp';
      default:
        return 'image/png';
    }
  }


  static int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    int cjkChars = 0;
    int otherChars = 0;
    for (final rune in text.runes) {
      if ((rune >= 0x3000 && rune <= 0x9FFF) ||
          (rune >= 0xF900 && rune <= 0xFAFF) ||
          (rune >= 0xFF00 && rune <= 0xFFEF)) {
        cjkChars++;
      } else {
        otherChars++;
      }
    }
    return cjkChars + (otherChars / 4).ceil();
  }

  Future<void> _recordAiTask(
    String convId,
    String msgId,
    AiService service,
    DateTime startedAt,
  ) async {
    try {
      final conv =
          state.conversations.where((c) => c.id == convId).firstOrNull;
      if (conv == null) return;
      final msg = conv.messages.where((m) => m.id == msgId).firstOrNull;
      if (msg == null) return;

      final estimatedTokens = _estimateTokens(msg.content);
      _updateMessage(
          convId, msgId, (m) => m.copyWith(completionTokens: estimatedTokens));

      final dao = ref.read(aiTaskDaoProvider);
      final now = DateTime.now();
      await dao.insertTask(AiTasksCompanion(
        id: Value(_uuid.v4()),
        type: const Value('chat'),
        status: const Value('completed'),
        provider: Value(service.providerName),
        model: Value(conv.model),
        inputPrompt: Value(conv.messages
            .where((m) => m.role == ChatRole.user)
            .map((m) => m.content)
            .join('\n---\n')),
        outputText: Value(msg.content),
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
  // Image processing
  // ---------------------------------------------------------------------------

  Future<List<String>> _persistImages(List<String> originalPaths) async {
    final dir = await _getChatDir();
    final imgDir = Directory(p.join(dir.path, 'images'));
    if (!await imgDir.exists()) await imgDir.create(recursive: true);

    final results = <String>[];
    for (final path in originalPaths) {
      try {
        final file = File(path);
        if (!await file.exists()) continue;
        var bytes = await file.readAsBytes();
        String ext = p.extension(path).toLowerCase();

        if (bytes.length > 1024 * 1024) {
          bytes = await compute(_compressImageSync, bytes);
          ext = '.jpg';
        }

        final filename = '${_uuid.v4()}$ext';
        final dest = File(p.join(imgDir.path, filename));
        await dest.writeAsBytes(bytes);
        results.add(dest.path);
      } catch (e) {
        _log.w('[ChatNotifier] Failed to persist image: $e');
        results.add(path);
      }
    }
    return results;
  }

  static Uint8List _compressImageSync(Uint8List bytes) {
    final image = img.decodeImage(bytes);
    if (image == null) return bytes;

    const maxDim = 2048;
    img.Image resized;
    if (image.width > maxDim || image.height > maxDim) {
      resized = image.width >= image.height
          ? img.copyResize(image, width: maxDim)
          : img.copyResize(image, height: maxDim);
    } else {
      resized = image;
    }
    return Uint8List.fromList(img.encodeJpg(resized, quality: 80));
  }

  // ---------------------------------------------------------------------------
  // Persistence (JSON files, versioned)
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
      final targetPath = p.join(dir.path, 'conversations.json');
      final tmpPath = '$targetPath.tmp';
      final tmpFile = File(tmpPath);

      final data = {
        'version': _jsonVersion,
        'conversations':
            state.conversations.map((c) => c.toJson()).toList(),
      };
      await tmpFile.writeAsString(jsonEncode(data));
      await tmpFile.rename(targetPath);
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
      final decoded = jsonDecode(content);

      List<dynamic> list;
      if (decoded is List) {
        list = decoded;
      } else if (decoded is Map<String, dynamic>) {
        list = decoded['conversations'] as List<dynamic>? ?? [];
      } else {
        return;
      }

      var convs = list
          .map((e) => Conversation.fromJson(e as Map<String, dynamic>))
          .toList();
      convs = convs.map(_cleanUpStaleStreamingMessages).toList();

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

  Conversation _cleanUpStaleStreamingMessages(Conversation conv) {
    final needsCleanup = conv.messages.any((m) => m.isStreaming);
    if (!needsCleanup) return conv;
    return conv.copyWith(
      messages: conv.messages.map((msg) {
        if (!msg.isStreaming) return msg;
        return msg.copyWith(
          isStreaming: false,
          error: msg.content.isEmpty ? '生成被中断（应用重启）' : null,
        );
      }).toList(),
    );
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
    } catch (e) {
      _log.w('[ChatNotifier] Failed to restore last model', error: e);
    }
  }

  Future<void> _saveLastModel(String providerId, String modelId) async {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(_prefsLastModelKey, '$providerId::$modelId');
    } catch (e) {
      _log.w('[ChatNotifier] Failed to save last model', error: e);
    }
  }
}
