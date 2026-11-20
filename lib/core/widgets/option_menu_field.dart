import 'package:material_ui/material_ui.dart';

class OptionMenuField<T> extends StatelessWidget {
  const OptionMenuField({
    required this.label,
    required this.valueLabel,
    required this.icon,
    required this.options,
    required this.onSelected,
    super.key,
  });

  final String label;
  final String valueLabel;
  final IconData icon;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => PopupMenuButton<T>(
    tooltip: label,
    onSelected: onSelected,
    itemBuilder: (context) => options
        .map(
          (option) => PopupMenuItem<T>(
            value: option.$1,
            child: Text(
              option.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    child: InputDecorator(
      isEmpty: false,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
      ),
      child: Text(valueLabel, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
  );
}
