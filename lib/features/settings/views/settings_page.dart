import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/platform_utils.dart';
import '../widgets/about_section.dart';
import '../widgets/ai_providers_section.dart';
import '../widgets/appearance_section.dart';
import '../widgets/extension_section.dart';
import '../widgets/network_section.dart';
import '../widgets/storage_section.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth <= Breakpoints.tablet;
          return ListView(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 16 : 24,
              vertical: 20,
            ),
            children: [
              const AiProvidersSection(),
              const SizedBox(height: 24),
              const StorageSection(),
              const SizedBox(height: 24),
              const AppearanceSection(),
              if (PlatformUtils.isDesktop) ...[
                const SizedBox(height: 24),
                const ExtensionSection(),
              ],
              const SizedBox(height: 24),
              const NetworkSection(),
              const SizedBox(height: 24),
              const AboutSection(),
              const SizedBox(height: 40),
            ],
          );
        },
      ),
    );
  }
}
