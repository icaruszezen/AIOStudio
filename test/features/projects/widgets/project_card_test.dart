import 'package:aio_studio/core/database/app_database.dart';
import 'package:aio_studio/features/projects/widgets/project_card.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Project _fakeProject({
  String name = 'Test Project',
  String? description,
  bool isArchived = false,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Project(
    id: 'proj-1',
    name: name,
    description: description,
    coverImagePath: null,
    createdAt: now,
    updatedAt: now,
    isArchived: isArchived,
  );
}

Widget _wrap(Widget child) {
  return FluentApp(home: ScaffoldPage(content: Center(child: SizedBox(
    width: 250,
    height: 280,
    child: child,
  ))));
}

void main() {
  group('ProjectCard', () {
    testWidgets('renders project name', (tester) async {
      await tester.pumpWidget(_wrap(
        ProjectCard(project: _fakeProject(name: 'My AI Project')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('My AI Project'), findsOneWidget);
    });

    testWidgets('renders description when provided', (tester) async {
      await tester.pumpWidget(_wrap(
        ProjectCard(
          project: _fakeProject(description: 'A cool project'),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('A cool project'), findsOneWidget);
    });

    testWidgets('displays asset count', (tester) async {
      await tester.pumpWidget(_wrap(
        ProjectCard(project: _fakeProject(), assetCount: 42),
      ));
      await tester.pumpAndSettle();

      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('shows gradient placeholder with initial letter', (tester) async {
      await tester.pumpWidget(_wrap(
        ProjectCard(project: _fakeProject(name: 'Zebra')),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Z'), findsOneWidget);
    });

    testWidgets('calls onTap callback when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(_wrap(
        ProjectCard(
          project: _fakeProject(),
          onTap: () => tapped = true,
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ProjectCard));
      expect(tapped, isTrue);
    });
  });
}
