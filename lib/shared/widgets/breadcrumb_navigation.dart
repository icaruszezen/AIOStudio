import 'package:fluent_ui/fluent_ui.dart';

class BreadcrumbEntry {
  const BreadcrumbEntry({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;
}

class BreadcrumbNavigation extends StatelessWidget {
  const BreadcrumbNavigation({
    super.key,
    required this.items,
  });

  final List<BreadcrumbEntry> items;

  @override
  Widget build(BuildContext context) {
    return BreadcrumbBar<int>(
      items: [
        for (var i = 0; i < items.length; i++)
          BreadcrumbItem(label: Text(items[i].label), value: i),
      ],
      onItemPressed: (item) {
        final entry = items[item.value];
        entry.onTap?.call();
      },
    );
  }
}
