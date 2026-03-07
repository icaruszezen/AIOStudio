import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/services/storage/local_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/format_utils.dart';

final _storageStatsProvider = FutureProvider<DetailedStorageStats>((ref) {
  return ref.watch(localStorageServiceProvider).getDetailedStorageStats();
});

final _storagePathProvider = FutureProvider<String>((ref) {
  return ref.watch(localStorageServiceProvider).getStoragePath();
});

class StorageSection extends ConsumerWidget {
  const StorageSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final statsAsync = ref.watch(_storageStatsProvider);
    final pathAsync = ref.watch(_storagePathProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(FluentIcons.folder_open, size: 20),
            const SizedBox(width: 8),
            Text('存储管理', style: theme.typography.subtitle),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Storage path
              Text('资产存储位置', style: theme.typography.bodyStrong),
              const SizedBox(height: 8),
              pathAsync.when(
                loading: () => const ProgressRing(),
                error: (e, _) => Text('$e'),
                data: (path) => Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.resources.subtleFillColorSecondary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          path,
                          style: theme.typography.caption,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Button(
                      onPressed: () => _openDirectory(path),
                      child: const Text('打开目录'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Storage statistics
              Text('存储统计', style: theme.typography.bodyStrong),
              const SizedBox(height: 12),
              statsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: ProgressRing()),
                ),
                error: (e, _) => InfoBar(
                  title: const Text('加载失败'),
                  content: Text('$e'),
                  severity: InfoBarSeverity.error,
                ),
                data: (stats) => _buildStats(context, stats, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(
    BuildContext context,
    DetailedStorageStats stats,
    WidgetRef ref,
  ) {
    final total = stats.totalSizeBytes;
    final b = FluentTheme.of(context).brightness;
    final imageColor = AppColors.imageGen(b);
    final videoColor = AppColors.videoGen(b);
    final otherColor = AppColors.pending(b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _StatItem(label: '总资产数量', value: '${stats.totalFiles} 个'),
            const SizedBox(width: 24),
            _StatItem(
              label: '总占用空间',
              value: formatFileSize(stats.totalSizeBytes),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _StorageBar(
          imageBytes: stats.imagesSizeBytes,
          videoBytes: stats.videosSizeBytes,
          otherBytes: stats.othersSizeBytes,
          totalBytes: total,
          imageColor: imageColor,
          videoColor: videoColor,
          otherColor: otherColor,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _LegendDot(color: imageColor, label: '图片 ${formatFileSize(stats.imagesSizeBytes)}'),
            const SizedBox(width: 16),
            _LegendDot(color: videoColor, label: '视频 ${formatFileSize(stats.videosSizeBytes)}'),
            const SizedBox(width: 16),
            _LegendDot(color: otherColor, label: '其他 ${formatFileSize(stats.othersSizeBytes)}'),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Button(
              onPressed: () => _clearCache(context, ref),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.delete, size: 14),
                  SizedBox(width: 6),
                  Text('清理缩略图缓存'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _openDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    final uri = Uri.file(path);
    await launchUrl(uri);
  }

  Future<void> _clearCache(BuildContext context, WidgetRef ref) async {
    try {
      final storage = ref.read(localStorageServiceProvider);
      await storage.clearThumbnailCache();
      ref.invalidate(_storageStatsProvider);
      if (context.mounted) {
        displayInfoBar(context, builder: (ctx, close) => InfoBar(
          title: const Text('缓存已清理'),
          severity: InfoBarSeverity.success,
          onClose: close,
        ));
      }
    } catch (e) {
      if (context.mounted) {
        displayInfoBar(context, builder: (ctx, close) => InfoBar(
          title: const Text('清理失败'),
          content: Text('$e'),
          severity: InfoBarSeverity.error,
          onClose: close,
        ));
      }
    }
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.typography.caption?.copyWith(
          color: theme.resources.textFillColorSecondary,
        )),
        const SizedBox(height: 2),
        Text(value, style: theme.typography.bodyStrong),
      ],
    );
  }
}

class _StorageBar extends StatelessWidget {
  const _StorageBar({
    required this.imageBytes,
    required this.videoBytes,
    required this.otherBytes,
    required this.totalBytes,
    required this.imageColor,
    required this.videoColor,
    required this.otherColor,
  });

  final int imageBytes;
  final int videoBytes;
  final int otherBytes;
  final int totalBytes;
  final Color imageColor;
  final Color videoColor;
  final Color otherColor;

  @override
  Widget build(BuildContext context) {
    if (totalBytes == 0) {
      return const SizedBox(
        height: 8,
        child: ProgressBar(value: 0),
      );
    }

    final imgFrac = imageBytes / totalBytes;
    final vidFrac = videoBytes / totalBytes;
    final otherFrac = otherBytes / totalBytes;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 8,
        child: Row(
          children: [
            if (imgFrac > 0)
              Flexible(
                flex: (imgFrac * 1000).round(),
                child: Container(color: imageColor),
              ),
            if (vidFrac > 0)
              Flexible(
                flex: (vidFrac * 1000).round(),
                child: Container(color: videoColor),
              ),
            if (otherFrac > 0)
              Flexible(
                flex: (otherFrac * 1000).round(),
                child: Container(color: otherColor),
              ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: FluentTheme.of(context).typography.caption),
      ],
    );
  }
}
