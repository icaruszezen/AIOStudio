import 'package:fluent_ui/fluent_ui.dart';

/// A vertical drag handle used between resizable panels.
///
/// Calls [onDrag] with the horizontal delta on each drag update.
class ResizableDivider extends StatelessWidget {
  const ResizableDivider({super.key, required this.onDrag});

  final ValueChanged<double> onDrag;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return GestureDetector(
      onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeColumn,
        child: Container(
          width: 4,
          color: theme.resources.cardStrokeColorDefault,
        ),
      ),
    );
  }
}
