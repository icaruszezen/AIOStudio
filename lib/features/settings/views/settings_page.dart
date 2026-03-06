import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/about_section.dart';
import '../widgets/ai_providers_section.dart';
import '../widgets/appearance_section.dart';
import '../widgets/extension_section.dart';
import '../widgets/storage_section.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ScaffoldPage(
      padding: EdgeInsets.zero,
      content: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: const [
          AiProvidersSection(),
          SizedBox(height: 24),
          StorageSection(),
          SizedBox(height: 24),
          AppearanceSection(),
          SizedBox(height: 24),
          ExtensionSection(),
          SizedBox(height: 24),
          AboutSection(),
          SizedBox(height: 40),
        ],
      ),
    );
  }
}
