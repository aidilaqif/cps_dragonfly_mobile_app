import 'package:flutter/material.dart';
import '../models/label_types.dart';

class LabelTypeFilter extends StatelessWidget {
  final List<LabelType> selectedTypes;
  final Function(List<LabelType>) onTypesChanged;

  const LabelTypeFilter({
    super.key,
    required this.selectedTypes,
    required this.onTypesChanged,
  });

  String _getLabelTypeName(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return 'FG Pallet';
      case LabelType.roll:
        return 'Roll';
      case LabelType.fgLocation:
        return 'FG Location';
      case LabelType.paperRollLocation:
        return 'Paper Roll Location';
    }
  }

  IconData _getLabelTypeIcon(LabelType type) {
    switch (type) {
      case LabelType.fgPallet:
        return Icons.inventory_2;
      case LabelType.roll:
        return Icons.rotate_right;
      case LabelType.fgLocation:
        return Icons.location_on;
      case LabelType.paperRollLocation:
        return Icons.location_searching;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...LabelType.values.map((type) {
          final isSelected = selectedTypes.contains(type);
          return FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getLabelTypeIcon(type),
                  size: 16,
                  color: isSelected ? Colors.white : Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(_getLabelTypeName(type)),
              ],
            ),
            selected: isSelected,
            onSelected: (selected) {
              final newTypes = List<LabelType>.from(selectedTypes);
              if (selected) {
                newTypes.add(type);
              } else {
                newTypes.remove(type);
              }
              onTypesChanged(newTypes);
            },
            backgroundColor: Colors.grey[200],
            selectedColor: Theme.of(context).colorScheme.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : Colors.black,
            ),
          );
        }).toList(),
      ],
    );
  }
}