import 'package:aio_studio/shared/widgets/empty_state.dart';
import 'package:aio_studio/shared/widgets/error_state.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return FluentApp(
    home: ScaffoldPage(content: child),
  );
}

void main() {
  group('EmptyState', () {
    testWidgets('renders icon and title', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(
          icon: FluentIcons.folder_open,
          title: '没有项目',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.folder_open), findsOneWidget);
      expect(find.text('没有项目'), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(
          icon: FluentIcons.folder_open,
          title: '没有项目',
          description: '点击创建按钮新建项目',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('点击创建按钮新建项目'), findsOneWidget);
    });

    testWidgets('hides description when null', (tester) async {
      await tester.pumpWidget(_wrap(
        const EmptyState(
          icon: FluentIcons.folder_open,
          title: '没有项目',
        ),
      ));
      await tester.pumpAndSettle();

      final texts = find.byType(Text);
      expect(texts, findsOneWidget);
    });

    testWidgets('renders action widget when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        EmptyState(
          icon: FluentIcons.add,
          title: '空',
          action: Button(
            onPressed: () {},
            child: const Text('新建'),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('新建'), findsOneWidget);
      expect(find.byType(Button), findsOneWidget);
    });
  });

  group('ErrorState', () {
    testWidgets('renders error icon and title', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorState(title: '加载失败'),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.error_badge), findsOneWidget);
      expect(find.text('加载失败'), findsOneWidget);
    });

    testWidgets('renders message when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorState(
          title: '出错了',
          message: '网络连接超时',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('网络连接超时'), findsOneWidget);
    });

    testWidgets('shows retry button when onRetry provided', (tester) async {
      var retried = false;
      await tester.pumpWidget(_wrap(
        ErrorState(
          title: '失败',
          onRetry: () => retried = true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('重试'), findsOneWidget);

      await tester.tap(find.text('重试'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(retried, isTrue);
    });

    testWidgets('hides retry button when onRetry is null', (tester) async {
      await tester.pumpWidget(_wrap(
        const ErrorState(title: '失败'),
      ));
      await tester.pumpAndSettle();

      expect(find.text('重试'), findsNothing);
    });
  });
}
