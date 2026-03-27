import 'package:aio_studio/core/database/app_database.dart';
import 'package:aio_studio/features/assets/widgets/asset_thumbnail.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

Asset _fakeAsset({
  String type = 'image',
  String? thumbnailPath,
  double? duration,
  bool isFavorite = false,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return Asset(
    id: 'asset-1',
    projectId: null,
    name: 'test_file',
    type: type,
    filePath: '/nonexistent/file.png',
    thumbnailPath: thumbnailPath,
    originalUrl: null,
    sourceType: 'local_import',
    fileSize: 1024,
    width: 100,
    height: 100,
    duration: duration,
    metadata: null,
    createdAt: now,
    updatedAt: now,
    isFavorite: isFavorite,
  );
}

Widget _wrap(Widget child) {
  return FluentApp(
    home: ScaffoldPage(
      content: SizedBox(width: 150, height: 150, child: child),
    ),
  );
}

void main() {
  group('AssetThumbnail', () {
    testWidgets('shows placeholder icon for audio type', (tester) async {
      await tester.pumpWidget(
        _wrap(AssetThumbnail(asset: _fakeAsset(type: 'audio'))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.music_in_collection), findsWidgets);
    });

    testWidgets('shows text document icon for text type', (tester) async {
      await tester.pumpWidget(
        _wrap(AssetThumbnail(asset: _fakeAsset(type: 'text'))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.text_document), findsWidgets);
    });

    testWidgets('shows play button overlay for video type', (tester) async {
      await tester.pumpWidget(
        _wrap(AssetThumbnail(asset: _fakeAsset(type: 'video'))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.play), findsOneWidget);
    });

    testWidgets('shows duration label for video with duration', (tester) async {
      await tester.pumpWidget(
        _wrap(
          AssetThumbnail(asset: _fakeAsset(type: 'video', duration: 125.0)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('02:05'), findsOneWidget);
    });

    testWidgets('shows favorite indicator when isFavorite is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          AssetThumbnail(asset: _fakeAsset(isFavorite: true), isFavorite: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.heart_fill), findsOneWidget);
    });

    testWidgets('shows selection overlay when isSelected', (tester) async {
      await tester.pumpWidget(
        _wrap(AssetThumbnail(asset: _fakeAsset(), isSelected: true)),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.check_mark), findsOneWidget);
    });

    testWidgets('shows generic icon for unknown type', (tester) async {
      await tester.pumpWidget(
        _wrap(AssetThumbnail(asset: _fakeAsset(type: 'other'))),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.document), findsWidgets);
    });
  });
}
