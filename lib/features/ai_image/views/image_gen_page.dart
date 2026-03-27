import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/platform_utils.dart';
import '../providers/image_gen_provider.dart';
import '../widgets/image_gen_history.dart';
import '../widgets/image_gen_params_panel.dart';
import '../widgets/image_gen_result_area.dart';

class ImageGenPage extends ConsumerStatefulWidget {
  const ImageGenPage({super.key});

  @override
  ConsumerState<ImageGenPage> createState() => _ImageGenPageState();
}

class _ImageGenPageState extends ConsumerState<ImageGenPage> {
  int _mobileTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final showHistory = ref.watch(
      imageGenProvider.select((s) => s.showHistory),
    );

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth <= Breakpoints.tablet) {
            return _buildMobileLayout(context, showHistory);
          }
          return _buildDesktopLayout(context, showHistory);
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context, bool showHistory) {
    return Row(
      children: [
        const SizedBox(width: 380, child: ImageGenParamsPanel()),
        const Divider(direction: Axis.vertical),
        Expanded(
          child: Column(
            children: [
              _buildToolbar(context, showHistory),
              const Divider(),
              Expanded(
                child: showHistory
                    ? const ImageGenHistory()
                    : const ImageGenResultArea(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context, bool showHistory) {
    return Column(
      children: [
        _buildMobileToolbar(context, showHistory),
        const Divider(),
        Expanded(
          child: _mobileTabIndex == 0
              ? const SingleChildScrollView(child: ImageGenParamsPanel())
              : showHistory
              ? const ImageGenHistory()
              : const ImageGenResultArea(),
        ),
      ],
    );
  }

  Widget _buildMobileToolbar(BuildContext context, bool showHistory) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Icon(FluentIcons.image_search, size: 18, color: theme.accentColor),
          const SizedBox(width: 6),
          Text('图片生成', style: theme.typography.bodyStrong),
          const Spacer(),
          ToggleButton(
            checked: _mobileTabIndex == 0,
            onChanged: (_) => setState(() => _mobileTabIndex = 0),
            child: const Text('参数'),
          ),
          const SizedBox(width: 4),
          ToggleButton(
            checked: _mobileTabIndex == 1,
            onChanged: (_) => setState(() => _mobileTabIndex = 1),
            child: const Text('结果'),
          ),
          if (_mobileTabIndex == 1) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                showHistory ? FluentIcons.image_pixel : FluentIcons.history,
                size: 14,
              ),
              onPressed: () =>
                  ref.read(imageGenProvider.notifier).toggleHistory(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, bool showHistory) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(FluentIcons.image_search, size: 20, color: theme.accentColor),
          const SizedBox(width: 8),
          Text('AI 图片生成', style: theme.typography.subtitle),
          const Spacer(),
          ToggleButton(
            checked: showHistory,
            onChanged: (_) =>
                ref.read(imageGenProvider.notifier).toggleHistory(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  showHistory ? FluentIcons.image_pixel : FluentIcons.history,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(showHistory ? '返回结果' : '生成历史'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
