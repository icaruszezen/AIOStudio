import 'package:fluent_ui/fluent_ui.dart';

IconData assetTypeIcon(String type) => switch (type) {
      'image' => FluentIcons.photo2,
      'video' => FluentIcons.video,
      'audio' => FluentIcons.music_in_collection,
      'text' => FluentIcons.text_document,
      _ => FluentIcons.document,
    };

String assetTypeLabel(String type) => switch (type) {
      'image' => '图片',
      'video' => '视频',
      'audio' => '音频',
      'text' => '文本',
      _ => '文件',
    };

String assetSourceLabel(String source) => switch (source) {
      'local_import' => '本地',
      'browser_extension' => '浏览器',
      'ai_generated' => 'AI',
      _ => source,
    };
