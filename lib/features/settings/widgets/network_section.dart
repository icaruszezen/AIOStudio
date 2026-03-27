import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/design_tokens.dart';
import '../providers/settings_provider.dart';

class NetworkSection extends ConsumerStatefulWidget {
  const NetworkSection({super.key});

  @override
  ConsumerState<NetworkSection> createState() => _NetworkSectionState();
}

class _NetworkSectionState extends ConsumerState<NetworkSection> {
  late TextEditingController _customController;
  bool _isCustom = false;

  @override
  void initState() {
    super.initState();
    _customController = TextEditingController();
    final current = ref.read(githubMirrorProvider);
    _isCustom = current.isNotEmpty && !githubMirrors.containsKey(current);
    if (_isCustom) {
      _customController.text = current;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  String get _comboValue {
    final current = ref.watch(githubMirrorProvider);
    if (githubMirrors.containsKey(current)) return current;
    return customMirrorValue;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(FluentIcons.globe, size: DesignTokens.iconLG),
            const SizedBox(width: DesignTokens.spacingSM),
            Text('网络加速', style: theme.typography.subtitle),
          ],
        ),
        const SizedBox(height: DesignTokens.spacingMD),
        Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '选择 GitHub 加速站可加快文件下载速度（软件更新、浏览器扩展等），适合无法直接访问 GitHub 的网络环境。仅加速文件下载，不影响网页浏览。',
                style: theme.typography.caption?.copyWith(
                  color: theme.resources.textFillColorSecondary,
                ),
              ),
              const SizedBox(height: DesignTokens.spacingLG),
              Text('GitHub 加速站', style: theme.typography.bodyStrong),
              const SizedBox(height: 10),
              ComboBox<String>(
                value: _comboValue,
                items: [
                  ...githubMirrors.entries.map(
                    (e) => ComboBoxItem(value: e.key, child: Text(e.value)),
                  ),
                  const ComboBoxItem(
                    value: customMirrorValue,
                    child: Text('自定义'),
                  ),
                ],
                onChanged: (val) {
                  if (val == null) return;
                  if (val == customMirrorValue) {
                    setState(() => _isCustom = true);
                    final text = _customController.text.trim();
                    if (text.isNotEmpty) {
                      final normalized = text.endsWith('/') ? text : '$text/';
                      ref
                          .read(githubMirrorProvider.notifier)
                          .setMirror(normalized);
                    } else {
                      ref.read(githubMirrorProvider.notifier).setMirror('');
                    }
                  } else {
                    setState(() => _isCustom = false);
                    ref.read(githubMirrorProvider.notifier).setMirror(val);
                  }
                },
                isExpanded: true,
              ),
              if (_isCustom) ...[
                const SizedBox(height: DesignTokens.spacingMD),
                InfoLabel(
                  label: '自定义加速站地址',
                  child: TextBox(
                    controller: _customController,
                    placeholder: 'https://your-mirror.example.com/',
                    onChanged: (val) {
                      final trimmed = val.trim();
                      if (trimmed.isNotEmpty) {
                        final normalized = trimmed.endsWith('/')
                            ? trimmed
                            : '$trimmed/';
                        ref
                            .read(githubMirrorProvider.notifier)
                            .setMirror(normalized);
                      } else {
                        ref.read(githubMirrorProvider.notifier).setMirror('');
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(height: DesignTokens.spacingMD),
              const _MirrorPreview(),
            ],
          ),
        ),
      ],
    );
  }
}

class _MirrorPreview extends ConsumerWidget {
  const _MirrorPreview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final mirror = ref.watch(githubMirrorProvider);
    final exampleFileUrl = githubReleaseAssetUrl(
      '1.0.0',
      extensionAssetName('1.0.0'),
    );
    final exampleUrl = resolveGithubUrl(exampleFileUrl, mirror);

    return Text(
      '下载示例：$exampleUrl',
      style: theme.typography.caption?.copyWith(
        color: theme.resources.textFillColorSecondary,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 2,
    );
  }
}
