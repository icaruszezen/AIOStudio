import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/settings_provider.dart';

class ExtensionSection extends ConsumerWidget {
  const ExtensionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final port = ref.watch(extensionPortProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(FluentIcons.plug, size: 20),
            const SizedBox(width: 8),
            Text('浏览器扩展', style: theme.typography.subtitle),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Port
              InfoLabel(
                label: '通信端口',
                child: SizedBox(
                  width: 160,
                  child: NumberBox<int>(
                    value: port,
                    min: 1024,
                    max: 65535,
                    onChanged: (val) {
                      if (val != null) {
                        ref.read(extensionPortProvider.notifier).setPort(val);
                      }
                    },
                    mode: SpinButtonPlacementMode.inline,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Connection status
              Row(
                children: [
                  Text('连接状态：', style: theme.typography.body),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '未连接',
                    style: theme.typography.body?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  Button(
                    onPressed: () {
                      displayInfoBar(context, builder: (ctx, close) => InfoBar(
                        title: const Text('功能开发中'),
                        content: const Text('通信服务重启功能将在后续版本中提供'),
                        severity: InfoBarSeverity.info,
                        onClose: close,
                      ));
                    },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.refresh, size: 14),
                        SizedBox(width: 6),
                        Text('重启通信服务'),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),

              // Download links
              Text('扩展下载', style: theme.typography.bodyStrong),
              const SizedBox(height: 8),
              Row(
                children: [
                  HyperlinkButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://chrome.google.com/webstore'),
                    ),
                    child: const Text('Chrome Web Store'),
                  ),
                  const SizedBox(width: 16),
                  HyperlinkButton(
                    onPressed: () => launchUrl(
                      Uri.parse('https://microsoftedge.microsoft.com/addons'),
                    ),
                    child: const Text('Edge Add-ons'),
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
