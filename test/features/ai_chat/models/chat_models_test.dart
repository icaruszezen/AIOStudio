import 'package:aio_studio/features/ai_chat/models/chat_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatRole', () {
    test('toJson returns name string', () {
      expect(ChatRole.user.toJson(), 'user');
      expect(ChatRole.assistant.toJson(), 'assistant');
      expect(ChatRole.system.toJson(), 'system');
    });

    test('fromJson parses known roles', () {
      expect(ChatRole.fromJson('user'), ChatRole.user);
      expect(ChatRole.fromJson('assistant'), ChatRole.assistant);
      expect(ChatRole.fromJson('system'), ChatRole.system);
    });

    test('fromJson defaults to user for unknown role', () {
      expect(ChatRole.fromJson('unknown'), ChatRole.user);
    });
  });

  group('ChatMessage', () {
    test('toJson/fromJson roundtrip', () {
      final msg = ChatMessage(
        id: 'msg-1',
        role: ChatRole.user,
        content: 'Hello',
        promptTokens: 10,
        completionTokens: 20,
        timestamp: DateTime(2025, 6, 15, 10, 30),
      );

      final json = msg.toJson();
      final restored = ChatMessage.fromJson(json);

      expect(restored.id, 'msg-1');
      expect(restored.role, ChatRole.user);
      expect(restored.content, 'Hello');
      expect(restored.promptTokens, 10);
      expect(restored.completionTokens, 20);
      expect(restored.timestamp, DateTime(2025, 6, 15, 10, 30));
    });

    test('totalTokens sums prompt and completion', () {
      final msg = ChatMessage(
        id: 'x',
        role: ChatRole.assistant,
        promptTokens: 50,
        completionTokens: 100,
      );
      expect(msg.totalTokens, 150);
    });

    test('totalTokens returns null when both are null', () {
      final msg = ChatMessage(id: 'x', role: ChatRole.user);
      expect(msg.totalTokens, isNull);
    });

    test('copyWith preserves unchanged fields', () {
      final msg = ChatMessage(
        id: 'msg-1',
        role: ChatRole.assistant,
        content: 'Hello',
        isStreaming: true,
      );

      final updated = msg.copyWith(content: 'Updated', isStreaming: false);
      expect(updated.id, 'msg-1');
      expect(updated.role, ChatRole.assistant);
      expect(updated.content, 'Updated');
      expect(updated.isStreaming, isFalse);
    });

    test('copyWith clearError removes error', () {
      final msg = ChatMessage(
        id: 'x',
        role: ChatRole.assistant,
        error: 'timeout',
      );

      final cleared = msg.copyWith(clearError: true);
      expect(cleared.error, isNull);
    });

    test('fromJson handles missing optional fields', () {
      final msg = ChatMessage.fromJson({
        'id': 'x',
        'role': 'user',
        'content': 'hi',
      });

      expect(msg.imagePaths, isNull);
      expect(msg.promptTokens, isNull);
      expect(msg.error, isNull);
    });

    test('imagePaths serialization roundtrip', () {
      final msg = ChatMessage(
        id: 'x',
        role: ChatRole.user,
        content: 'with images',
        imagePaths: ['/path/a.png', '/path/b.jpg'],
      );

      final restored = ChatMessage.fromJson(msg.toJson());
      expect(restored.imagePaths, ['/path/a.png', '/path/b.jpg']);
    });
  });

  group('Conversation', () {
    test('toJson/fromJson roundtrip', () {
      final conv = Conversation(
        id: 'conv-1',
        title: 'Test Chat',
        providerId: 'openai',
        model: 'gpt-4o',
        systemPrompt: 'You are helpful',
        messages: [
          ChatMessage(id: 'msg-1', role: ChatRole.user, content: 'Hi'),
          ChatMessage(
              id: 'msg-2', role: ChatRole.assistant, content: 'Hello!'),
        ],
      );

      final json = conv.toJson();
      final restored = Conversation.fromJson(json);

      expect(restored.id, 'conv-1');
      expect(restored.title, 'Test Chat');
      expect(restored.providerId, 'openai');
      expect(restored.model, 'gpt-4o');
      expect(restored.systemPrompt, 'You are helpful');
      expect(restored.messages, hasLength(2));
    });

    test('toJsonString/fromJsonString roundtrip', () {
      final conv = Conversation(
        id: 'c1',
        title: 'Quick',
        providerId: 'p1',
        model: 'm1',
      );

      final jsonStr = conv.toJsonString();
      final restored = Conversation.fromJsonString(jsonStr);
      expect(restored.id, 'c1');
      expect(restored.title, 'Quick');
    });

    test('lastMessage returns last message or null', () {
      final empty = Conversation(
        id: 'c1',
        title: 'Empty',
        providerId: '',
        model: '',
      );
      expect(empty.lastMessage, isNull);

      final withMsg = empty.copyWith(messages: [
        ChatMessage(id: 'm1', role: ChatRole.user, content: 'Last'),
      ]);
      expect(withMsg.lastMessage!.content, 'Last');
    });

    test('copyWith clearSystemPrompt sets null', () {
      final conv = Conversation(
        id: 'c1',
        title: 'T',
        providerId: '',
        model: '',
        systemPrompt: 'Be helpful',
      );

      final cleared = conv.copyWith(clearSystemPrompt: true);
      expect(cleared.systemPrompt, isNull);
    });

    test('messages default to empty list', () {
      final conv = Conversation(
        id: 'c1',
        title: 'T',
        providerId: '',
        model: '',
      );
      expect(conv.messages, isEmpty);
    });
  });

  group('SelectedModel', () {
    test('displayName combines provider and model', () {
      const sm = SelectedModel(
        providerId: 'openai',
        providerName: 'OpenAI',
        modelId: 'gpt-4o',
      );
      expect(sm.displayName, 'OpenAI / gpt-4o');
    });

    test('storageKey format', () {
      const sm = SelectedModel(
        providerId: 'openai',
        providerName: 'OpenAI',
        modelId: 'gpt-4o',
      );
      expect(sm.storageKey, 'openai::gpt-4o');
    });

    test('fromStorageKey parses correctly', () {
      final sm = SelectedModel.fromStorageKey('openai::gpt-4o', 'OpenAI');
      expect(sm.providerId, 'openai');
      expect(sm.modelId, 'gpt-4o');
    });

    test('fromStorageKey handles missing separator', () {
      final sm = SelectedModel.fromStorageKey('openai', 'OpenAI');
      expect(sm.providerId, 'openai');
      expect(sm.modelId, '');
    });
  });
}
