import 'package:aio_studio/features/ai_chat/models/chat_models.dart';
import 'package:aio_studio/features/ai_chat/widgets/chat_message_bubble.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage _userMessage({String content = 'Hello!'}) {
  return ChatMessage(
    id: 'msg-user',
    role: 'user',
    content: content,
    timestamp: DateTime(2025, 1, 15, 14, 30),
  );
}

ChatMessage _assistantMessage({
  String content = 'Hi there!',
  bool isStreaming = false,
  int? totalTokens,
  String? error,
}) {
  return ChatMessage(
    id: 'msg-ai',
    role: 'assistant',
    content: content,
    timestamp: DateTime(2025, 1, 15, 14, 31),
    isStreaming: isStreaming,
    promptTokens: totalTokens != null ? totalTokens ~/ 2 : null,
    completionTokens: totalTokens != null ? totalTokens ~/ 2 : null,
    error: error,
  );
}

Widget _wrap(Widget child) {
  return FluentApp(
    home: ScaffoldPage(
      content: SingleChildScrollView(child: child),
    ),
  );
}

void main() {
  group('ChatMessageBubble', () {
    testWidgets('renders user message content', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatMessageBubble(
          message: _userMessage(content: 'How are you?'),
          isDarkMode: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('How are you?'), findsOneWidget);
    });

    testWidgets('shows user avatar for user messages', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatMessageBubble(
          message: _userMessage(),
          isDarkMode: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.contact), findsOneWidget);
    });

    testWidgets('shows AI avatar for assistant messages', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatMessageBubble(
          message: _assistantMessage(),
          isDarkMode: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.robot), findsOneWidget);
    });

    testWidgets('shows timestamp in footer', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatMessageBubble(
          message: _userMessage(),
          isDarkMode: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('shows typing indicator when streaming with empty content', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatMessageBubble(
          message: _assistantMessage(content: '', isStreaming: true),
          isDarkMode: false,
        ),
      ));
      await tester.pump();

      expect(find.text('思考中...'), findsOneWidget);
      expect(find.byType(ProgressRing), findsOneWidget);
    });

    testWidgets('shows error icon and message for error state', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatMessageBubble(
          message: _assistantMessage(error: '连接超时'),
          isDarkMode: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.error_badge), findsOneWidget);
      expect(find.text('连接超时'), findsOneWidget);
    });

    testWidgets('shows token count for assistant messages', (tester) async {
      await tester.pumpWidget(_wrap(
        ChatMessageBubble(
          message: _assistantMessage(totalTokens: 150),
          isDarkMode: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('150 tokens'), findsOneWidget);
    });
  });
}
