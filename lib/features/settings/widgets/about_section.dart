import 'package:fluent_ui/fluent_ui.dart';
import 'package:url_launcher/url_launcher.dart';

const _appVersion = '1.0.0';
const _appBuild = '1';

// TODO: replace with actual repository URL once available
const _repoUrl = 'https://github.com';
const _issuesUrl = 'https://github.com';

class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

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
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      FluentIcons.a_a_d_logo,
                      size: 24,
                      color: theme.accentColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AIO Studio', style: theme.typography.subtitle),
                      const SizedBox(height: 2),
                      Text(
                        '版本 $_appVersion (Build $_appBuild)',
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
                      displayInfoBar(context, builder: (ctx, close) => InfoBar(
                        title: const Text('已是最新版本'),
                        severity: InfoBarSeverity.success,
                        onClose: close,
                      ));
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
                    onPressed: () => launchUrl(Uri.parse(_repoUrl)),
                    child: const Text('开源仓库'),
                  ),
                  const SizedBox(width: 12),
                  HyperlinkButton(
                    onPressed: () => launchUrl(Uri.parse(_issuesUrl)),
                    child: const Text('反馈问题'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'MIT License',
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
