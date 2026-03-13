import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/extension_bridge/extension_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/settings_provider.dart';
import 'about_section.dart' show packageInfoProvider;

class ExtensionSection extends ConsumerWidget {
  const ExtensionSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final b = theme.brightness;
    final port = ref.watch(extensionPortProvider);
    final actualPort = ref.watch(extensionActualPortProvider);
    final serverState = ref.watch(extensionServerProvider);
    final connected = ref.watch(extensionConnectionStatusProvider);

    final mirror = ref.watch(githubMirrorProvider);
    final packageInfo = ref.watch(packageInfoProvider);
    final isRunning = serverState.value == true;

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
              // Server status
              Row(
                children: [
                  Text('服务状态：', style: theme.typography.body),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: serverState.isLoading
                          ? AppColors.warning(b)
                          : isRunning
                              ? AppColors.success(b)
                              : AppColors.error(b),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    serverState.isLoading
                        ? '启动中...'
                        : isRunning
                            ? '运行中 (端口 $actualPort)'
                            : '已停止',
                    style: theme.typography.body,
                  ),
                ],
              ),
              if (serverState.hasError) ...[
                const SizedBox(height: 8),
                Text(
                  '错误：${serverState.error}',
                  style: theme.typography.body
                      ?.copyWith(color: AppColors.error(b)),
                ),
              ],
              const SizedBox(height: 16),

              // Port config
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
                        ref
                            .read(extensionPortProvider.notifier)
                            .setPort(val);
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
                  Text('扩展连接：', style: theme.typography.body),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: connected ? AppColors.success(b) : AppColors.pending(b),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    connected ? '已连接' : '未连接',
                    style: theme.typography.body?.copyWith(
                      color: connected ? AppColors.success(b) : AppColors.pending(b),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Actions
              Row(
                children: [
                  ToggleSwitch(
                    checked: isRunning,
                    onChanged: serverState.isLoading
                        ? null
                        : (val) {
                            if (val) {
                              ref
                                  .read(extensionServerProvider.notifier)
                                  .startServer();
                            } else {
                              ref
                                  .read(extensionServerProvider.notifier)
                                  .stopServer();
                            }
                          },
                    content: Text(isRunning ? '已启用' : '已停用'),
                  ),
                  const SizedBox(width: 16),
                  Button(
                    onPressed: serverState.isLoading
                        ? null
                        : () {
                            ref
                                .read(extensionServerProvider.notifier)
                                .restart();
                          },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.refresh, size: 14),
                        SizedBox(width: 6),
                        Text('重启服务'),
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
              Text(
                '下载编译好的浏览器扩展，解压后在浏览器扩展页面启用「开发者模式」并「加载已解压的扩展程序」。',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Button(
                    onPressed: !packageInfo.hasValue
                        ? null
                        : () {
                            final version = packageInfo.value!.version;
                            final asset = extensionAssetName(version);
                            final fileUrl =
                                githubReleaseAssetUrl(version, asset);
                            launchUrl(
                              Uri.parse(resolveGithubUrl(fileUrl, mirror)),
                            );
                          },
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.download, size: 14),
                        SizedBox(width: 6),
                        Text('下载扩展'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  HyperlinkButton(
                    onPressed: () => launchUrl(
                      Uri.parse('$githubBaseUrl/releases'),
                    ),
                    child: const Text('所有版本'),
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
