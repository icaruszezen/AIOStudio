import 'package:aio_studio/core/database/app_database.dart';
import 'package:aio_studio/features/prompts/widgets/prompt_card.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Prompt _fakePrompt({
  String title = 'Test Prompt',
  String content = 'Hello {{name}}',
  String? category,
  bool isFavorite = false,
  int useCount = 0,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Prompt(
    id: 'prompt-1',
    projectId: null,
    title: title,
    content: content,
    category: category,
    variables: null,
    isFavorite: isFavorite,
    useCount: useCount,
    createdAt: now,
    updatedAt: now,
  );
}

Widget _wrap(Widget child) {
  return FluentApp(
    home: ScaffoldPage(content: SizedBox(width: 400, height: 60, child: child)),
  );
}

void main() {
  group('PromptCard', () {
    testWidgets('renders prompt title and content preview', (tester) async {
      await tester.pumpWidget(
        _wrap(
          PromptCard(
            prompt: _fakePrompt(title: 'My Prompt', content: 'Do stuff'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Prompt'), findsOneWidget);
      expect(find.text('Do stuff'), findsOneWidget);
    });

    testWidgets('shows favorite icon when isFavorite is true', (tester) async {
      await tester.pumpWidget(
        _wrap(PromptCard(prompt: _fakePrompt(isFavorite: true))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.heart_fill), findsOneWidget);
    });

    testWidgets('hides favorite icon when isFavorite is false', (tester) async {
      await tester.pumpWidget(
        _wrap(PromptCard(prompt: _fakePrompt(isFavorite: false))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.heart_fill), findsNothing);
    });

    testWidgets('shows use count when greater than zero', (tester) async {
      await tester.pumpWidget(
        _wrap(PromptCard(prompt: _fakePrompt(useCount: 5))),
      );
      await tester.pumpAndSettle();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('hides use count when zero', (tester) async {
      await tester.pumpWidget(
        _wrap(PromptCard(prompt: _fakePrompt(useCount: 0))),
      );
      await tester.pumpAndSettle();

      expect(find.text('0'), findsNothing);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(PromptCard(prompt: _fakePrompt(), onTap: () => tapped = true)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(PromptCard));
      expect(tapped, isTrue);
    });

    testWidgets('shows category icon for different categories', (tester) async {
      await tester.pumpWidget(
        _wrap(PromptCard(prompt: _fakePrompt(category: 'chat'))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.chat), findsOneWidget);
    });

    testWidgets('shows image_gen category icon', (tester) async {
      await tester.pumpWidget(
        _wrap(PromptCard(prompt: _fakePrompt(category: 'image_gen'))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.photo2), findsOneWidget);
    });
  });

  group('promptCategoryIcon', () {
    test('returns correct icons for known categories', () {
      expect(promptCategoryIcon('text_gen'), FluentIcons.text_document);
      expect(promptCategoryIcon('image_gen'), FluentIcons.photo2);
      expect(promptCategoryIcon('video_gen'), FluentIcons.video);
      expect(promptCategoryIcon('chat'), FluentIcons.chat);
      expect(promptCategoryIcon('optimization'), FluentIcons.auto_enhance_on);
      expect(promptCategoryIcon('other'), FluentIcons.more);
    });

    test('returns default icon for null/unknown category', () {
      expect(promptCategoryIcon(null), FluentIcons.text_document);
      expect(promptCategoryIcon('unknown'), FluentIcons.text_document);
    });
  });
}
