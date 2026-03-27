import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';

final packageInfoProvider = FutureProvider<PackageInfo>((ref) {
  return PackageInfo.fromPlatform();
});

class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final packageInfo = ref.watch(packageInfoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(FluentIcons.info, size: 20),
            const SizedBox(width: 8),
            Text('关于', style: theme.typography.subtitle),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 48,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AIO Studio', style: theme.typography.subtitle),
                      const SizedBox(height: 2),
                      Text(
                        packageInfo.when(
                          data: (info) =>
                              '版本 ${info.version} (Build ${info.buildNumber})',
                          loading: () => '版本 ...',
                          error: (_, __) => '版本 未知',
                        ),
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '跨平台 AGI 项目与资产管理应用',
                style: theme.typography.body?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  Button(
                    onPressed: () {
                      displayInfoBar(
                        context,
                        builder: (ctx, close) => InfoBar(
                          title: const Text('已是最新版本'),
                          severity: InfoBarSeverity.success,
                          onClose: close,
                        ),
                      );
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.sync, size: 14),
                        SizedBox(width: 6),
                        Text('检查更新'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Row(
                children: [
                  HyperlinkButton(
                    onPressed: () => launchUrl(Uri.parse(githubBaseUrl)),
                    child: const Text('开源仓库'),
                  ),
                  const SizedBox(width: 12),
                  HyperlinkButton(
                    onPressed: () =>
                        launchUrl(Uri.parse('$githubBaseUrl/issues')),
                    child: const Text('反馈问题'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'AGPL-3.0 License',
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
