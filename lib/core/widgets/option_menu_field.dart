import 'package:material_ui/material_ui.dart';

class OptionMenuField<T> extends StatelessWidget {
  const OptionMenuField({
    required this.label,
    required this.value,
    required this.icon,
    required this.options,
    required this.onSelected,
    this.hint,
    super.key,
  });

  final String label;
  final T? value;
  final IconData icon;
  final List<(T, String)> options;
  final ValueChanged<T> onSelected;
  final String? hint;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    key: ValueKey(value),
    initialValue: value,
    isExpanded: true,
    menuMaxHeight: 320,
    borderRadius: BorderRadius.circular(16),
    dropdownColor: Theme.of(context).colorScheme.surface,
    hint: Text(hint ?? 'Selecione uma opção'),
    decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    items: options
        .map(
          (option) => DropdownMenuItem<T>(
            value: option.$1,
            child: Text(
              option.$2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(growable: false),
    onChanged: (selected) {
      if (selected != null) onSelected(selected);
    },
  );
}
