import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/image_gen_provider.dart';
import '../widgets/image_gen_history.dart';
import '../widgets/image_gen_params_panel.dart';
import '../widgets/image_gen_result_area.dart';

class ImageGenPage extends ConsumerWidget {
  const ImageGenPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showHistory = ref.watch(
      imageGenProvider.select((s) => s.showHistory),
    );

    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: Row(
        children: [
          // Left panel – parameters (~35%)
          const SizedBox(
            width: 380,
            child: ImageGenParamsPanel(),
          ),
          const Divider(direction: Axis.vertical),
          // Right panel – results / history (~65%)
          Expanded(
            child: Column(
              children: [
                _buildToolbar(context, ref, showHistory),
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
      ),
    );
  }

  Widget _buildToolbar(BuildContext context, WidgetRef ref, bool showHistory) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            FluentIcons.image_search,
            size: 20,
            color: theme.accentColor,
          ),
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
