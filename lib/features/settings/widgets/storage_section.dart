import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/providers/database_provider.dart';
import '../../../core/services/storage/local_storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../shared/utils/error_utils.dart';
import '../../../shared/utils/format_utils.dart';
import '../providers/settings_provider.dart';

final _storageStatsProvider = FutureProvider.autoDispose<DetailedStorageStats>((
  ref,
) {
  return ref.watch(localStorageServiceProvider).getDetailedStorageStats();
});

final _storagePathProvider = FutureProvider.autoDispose<String>((ref) {
  return ref.watch(localStorageServiceProvider).getStoragePath();
});

class StorageSection extends ConsumerStatefulWidget {
  const StorageSection({super.key});

  @override
  ConsumerState<StorageSection> createState() => _StorageSectionState();
}

class _StorageSectionState extends ConsumerState<StorageSection> {
  bool _isMigrating = false;
  int _migrationCurrent = 0;
  int _migrationTotal = 0;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final statsAsync = ref.watch(_storageStatsProvider);
    final pathAsync = ref.watch(_storagePathProvider);
    final customDir = ref.watch(storageDirectoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(theme),
        const SizedBox(height: DesignTokens.spacingMD),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCacheDirectoryIntro(theme),
              _buildPathPickerArea(theme, pathAsync, customDir),
              ..._buildMigrationSection(theme),
              const SizedBox(height: DesignTokens.spacingLG),
              const Divider(),
              const SizedBox(height: DesignTokens.spacingLG),
              _buildStatsUsageSection(context, theme, statsAsync),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(FluentThemeData theme) {
    return Row(
      children: [
        const Icon(FluentIcons.folder_open, size: DesignTokens.iconLG),
        const SizedBox(width: DesignTokens.spacingSM),
        Text('存储管理', style: theme.typography.subtitle),
      ],
    );
  }

  Widget _buildCacheDirectoryIntro(FluentThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('缓存目录', style: theme.typography.bodyStrong),
        const SizedBox(height: DesignTokens.spacingXS),
        Text(
          '缩略图和下载的资产文件将保存在此目录中',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        const SizedBox(height: DesignTokens.spacingSM),
      ],
    );
  }

  Widget _buildPathPickerArea(
    FluentThemeData theme,
    AsyncValue<String> pathAsync,
    String? customDir,
  ) {
    return pathAsync.when(
      loading: () => const ProgressRing(),
      error: (e, _) => Text(formatUserError(e)),
      data: (path) => _buildPathPickerContent(theme, path, customDir),
    );
  }

  Widget _buildPathPickerContent(
    FluentThemeData theme,
    String path,
    String? customDir,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPathDisplayRow(theme, path, customDir),
        const SizedBox(height: DesignTokens.spacingSM),
        _buildPathActionButtons(path, customDir),
      ],
    );
  }

  Widget _buildPathDisplayRow(
    FluentThemeData theme,
    String path,
    String? customDir,
  ) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: theme.resources.subtleFillColorSecondary,
              borderRadius: DesignTokens.borderRadiusSM,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    path,
                    style: theme.typography.caption,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (customDir != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.accentColor.withValues(alpha: 0.15),
                        borderRadius: DesignTokens.borderRadiusSM,
                      ),
                      child: Text(
                        '自定义',
                        style: theme.typography.caption?.copyWith(
                          color: theme.accentColor,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPathActionButtons(String path, String? customDir) {
    return Wrap(
      spacing: DesignTokens.spacingSM,
      runSpacing: DesignTokens.spacingSM,
      children: [
        Button(
          onPressed: _isMigrating ? null : _selectDirectory,
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.fabric_folder, size: DesignTokens.iconSM),
              SizedBox(width: 6),
              Text('选择目录'),
            ],
          ),
        ),
        if (customDir != null)
          Button(
            onPressed: _isMigrating ? null : _resetToDefault,
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.reset, size: DesignTokens.iconSM),
                SizedBox(width: 6),
                Text('恢复默认'),
              ],
            ),
          ),
        Button(
          onPressed: () => _openDirectory(path),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.open_folder_horizontal,
                size: DesignTokens.iconSM,
              ),
              SizedBox(width: 6),
              Text('打开目录'),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMigrationSection(FluentThemeData theme) {
    if (!_isMigrating) return const [];
    return [
      const SizedBox(height: DesignTokens.spacingMD),
      _buildMigrationProgress(theme),
    ];
  }

  Widget _buildStatsUsageSection(
    BuildContext context,
    FluentThemeData theme,
    AsyncValue<DetailedStorageStats> statsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('存储统计', style: theme.typography.bodyStrong),
        const SizedBox(height: DesignTokens.spacingMD),
        statsAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(DesignTokens.spacingMD),
            child: Center(child: ProgressRing()),
          ),
          error: (e, _) => InfoBar(
            title: const Text('加载失败'),
            content: Text(formatUserError(e)),
            severity: InfoBarSeverity.error,
          ),
          data: (stats) => _buildStats(context, stats),
        ),
      ],
    );
  }

  Widget _buildMigrationProgress(FluentThemeData theme) {
    final progress = _migrationTotal > 0
        ? _migrationCurrent / _migrationTotal
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: ProgressRing(strokeWidth: 2),
            ),
            const SizedBox(width: DesignTokens.spacingSM),
            Text(
              _migrationTotal > 0
                  ? '正在迁移... $_migrationCurrent / $_migrationTotal'
                  : '正在准备迁移...',
              style: theme.typography.caption,
            ),
          ],
        ),
        const SizedBox(height: 6),
        ProgressBar(value: progress != null ? progress * 100 : null),
      ],
    );
  }

  Widget _buildStats(BuildContext context, DetailedStorageStats stats) {
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
            _StatItem(label: '总文件数量', value: '${stats.totalFiles} 个'),
            const SizedBox(width: DesignTokens.spacingXL),
            _StatItem(
              label: '总占用空间',
              value: formatFileSize(stats.totalSizeBytes),
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacingLG),
        _StorageBar(
          imageBytes: stats.imagesSizeBytes,
          videoBytes: stats.videosSizeBytes,
          otherBytes: stats.othersSizeBytes,
          totalBytes: total,
          imageColor: imageColor,
          videoColor: videoColor,
          otherColor: otherColor,
        ),
        const SizedBox(height: DesignTokens.spacingSM),
        Row(
          children: [
            _LegendDot(
              color: imageColor,
              label: '图片 ${formatFileSize(stats.imagesSizeBytes)}',
            ),
            const SizedBox(width: DesignTokens.spacingLG),
            _LegendDot(
              color: videoColor,
              label: '视频 ${formatFileSize(stats.videosSizeBytes)}',
            ),
            const SizedBox(width: DesignTokens.spacingLG),
            _LegendDot(
              color: otherColor,
              label: '其他 ${formatFileSize(stats.othersSizeBytes)}',
            ),
          ],
        ),
        const SizedBox(height: DesignTokens.spacingLG),
        Row(
          children: [
            Button(
              onPressed: _clearCache,
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.delete, size: DesignTokens.iconSM),
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

  Future<void> _selectDirectory() async {
    final newPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '选择缓存目录',
    );
    if (newPath == null || !mounted) return;

    final oldPath = await ref
        .read(localStorageServiceProvider)
        .getStoragePath();

    if (newPath == oldPath) return;

    final action = await _showMigrationDialog();
    if (action == null || !mounted) return;

    if (action == _MigrationAction.migrateAndSwitch) {
      final ok = await _performMigration(oldPath, newPath);
      if (!ok || !mounted) return;
    }

    if (!mounted) return;
    await ref.read(storageDirectoryProvider.notifier).setDirectory(newPath);
    ref
      ..invalidate(_storagePathProvider)
      ..invalidate(_storageStatsProvider);

    if (mounted) {
      displayInfoBar(
        context,
        builder: (_, close) => InfoBar(
          title: Text(
            action == _MigrationAction.migrateAndSwitch
                ? '缓存目录已迁移并切换'
                : '缓存目录已切换',
          ),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    final currentPath = await ref
        .read(localStorageServiceProvider)
        .getStoragePath();
    final defaultPath = await LocalStorageService.defaultCachePath;

    if (currentPath == defaultPath) return;

    final action = await _showMigrationDialog();
    if (action == null || !mounted) return;

    if (action == _MigrationAction.migrateAndSwitch) {
      final ok = await _performMigration(currentPath, defaultPath);
      if (!ok || !mounted) return;
    }

    if (!mounted) return;
    await ref.read(storageDirectoryProvider.notifier).setDirectory(null);
    ref
      ..invalidate(_storagePathProvider)
      ..invalidate(_storageStatsProvider);

    if (mounted) {
      displayInfoBar(
        context,
        builder: (_, close) => InfoBar(
          title: Text(
            action == _MigrationAction.migrateAndSwitch
                ? '已迁移并恢复默认目录'
                : '已恢复默认目录',
          ),
          severity: InfoBarSeverity.success,
          onClose: close,
        ),
      );
    }
  }

  Future<_MigrationAction?> _showMigrationDialog() async {
    return showDialog<_MigrationAction>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('更改缓存目录'),
        content: const Text(
          '是否将当前缓存目录中的资源迁移到新目录？\n\n'
          '选择「迁移并切换」会将所有缓存文件（缩略图、下载的资产等）'
          '移动到新目录，并更新数据库中的路径。\n\n'
          '选择「仅切换」会直接切换目录，旧缓存保留在原位置。',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('取消'),
          ),
          Button(
            onPressed: () => Navigator.of(ctx).pop(_MigrationAction.switchOnly),
            child: const Text('仅切换'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(_MigrationAction.migrateAndSwitch),
            child: const Text('迁移并切换'),
          ),
        ],
      ),
    );
  }

  Future<bool> _performMigration(String oldRoot, String newRoot) async {
    setState(() {
      _isMigrating = true;
      _migrationCurrent = 0;
      _migrationTotal = 0;
    });

    try {
      final storage = ref.read(localStorageServiceProvider);
      await storage.migrateCache(
        oldRoot: oldRoot,
        newRoot: newRoot,
        onProgress: (current, total) {
          if (mounted) {
            setState(() {
              _migrationCurrent = current;
              _migrationTotal = total;
            });
          }
        },
      );

      final assetDao = ref.read(assetDaoProvider);
      await assetDao.updatePathPrefix(oldRoot, newRoot);
      return true;
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (_, close) => InfoBar(
            title: const Text('迁移失败'),
            content: Text(formatUserError(e)),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
      return false;
    } finally {
      if (mounted) {
        setState(() => _isMigrating = false);
      }
    }
  }

  Future<void> _openDirectory(String path) async {
    final dir = Directory(path);
    if (!await dir.exists()) await dir.create(recursive: true);
    final uri = Uri.file(path);
    await launchUrl(uri);
  }

  Future<void> _clearCache() async {
    try {
      final storage = ref.read(localStorageServiceProvider);
      await storage.clearThumbnailCache();
      await ref.read(assetDaoProvider).clearAllThumbnailPaths();
      ref.invalidate(_storageStatsProvider);
      if (mounted) {
        displayInfoBar(
          context,
          builder: (_, close) => InfoBar(
            title: const Text('缓存已清理'),
            severity: InfoBarSeverity.success,
            onClose: close,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        displayInfoBar(
          context,
          builder: (_, close) => InfoBar(
            title: const Text('清理失败'),
            content: Text(formatUserError(e)),
            severity: InfoBarSeverity.error,
            onClose: close,
          ),
        );
      }
    }
  }
}

enum _MigrationAction { migrateAndSwitch, switchOnly }

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
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
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
      return const SizedBox(height: 8, child: ProgressBar(value: 0));
    }

    final imgFrac = imageBytes / totalBytes;
    final vidFrac = videoBytes / totalBytes;
    final otherFrac = otherBytes / totalBytes;

    return ClipRRect(
      borderRadius: DesignTokens.borderRadiusSM,
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
        const SizedBox(width: DesignTokens.spacingXS),
        Text(label, style: FluentTheme.of(context).typography.caption),
      ],
    );
  }
}
