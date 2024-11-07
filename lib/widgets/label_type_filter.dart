import 'package:flutter/material.dart';
import '../models/label_types.dart';

class LabelTypeFilter extends StatelessWidget {
  final List<LabelType> selectedTypes;
  final Function(List<LabelType>) onTypesChanged;
  final bool showSelectAll;
  final bool showCount;
  final Map<LabelType, int>? typeCounts;
  final bool compactMode;
  final EdgeInsets? padding;

  const LabelTypeFilter({
    super.key,
    required this.selectedTypes,
    required this.onTypesChanged,
    this.showSelectAll = true,
    this.showCount = false,
    this.typeCounts,
    this.compactMode = false,
    this.padding,
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

  Color _getLabelTypeColor(LabelType type, bool isSelected) {
    if (!isSelected) return Colors.grey;
    
    switch (type) {
      case LabelType.fgPallet:
        return Colors.blue;
      case LabelType.roll:
        return Colors.green;
      case LabelType.fgLocation:
        return Colors.orange;
      case LabelType.paperRollLocation:
        return Colors.purple;
    }
  }

  void _handleSelectAll() {
    if (selectedTypes.length == LabelType.values.length) {
      // If all are selected, clear selection
      onTypesChanged([]);
    } else {
      // Otherwise, select all
      onTypesChanged(LabelType.values.toList());
    }
  }

  void _toggleType(LabelType type) {
    final newTypes = List<LabelType>.from(selectedTypes);
    if (selectedTypes.contains(type)) {
      newTypes.remove(type);
    } else {
      newTypes.add(type);
    }
    onTypesChanged(newTypes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showSelectAll) ...[
          Padding(
            padding: padding ?? const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Text(
                  'Label Types',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _handleSelectAll,
                  icon: Icon(
                    selectedTypes.length == LabelType.values.length
                        ? Icons.clear_all
                        : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    selectedTypes.length == LabelType.values.length
                        ? 'Clear All'
                        : 'Select All',
                    style: const TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (compactMode)
          _buildCompactView(context)
        else
          _buildExpandedView(context),
      ],
    );
  }

  Widget _buildExpandedView(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: LabelType.values.map((type) {
        final isSelected = selectedTypes.contains(type);
        final count = typeCounts?[type] ?? 0;
        
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
              if (showCount && typeCounts != null) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      color: isSelected ? Colors.white : Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
          selected: isSelected,
          onSelected: (_) => _toggleType(type),
          checkmarkColor: Colors.white,
          backgroundColor: Colors.grey[200],
          selectedColor: _getLabelTypeColor(type, true),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.black,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          elevation: 0,
          pressElevation: 2,
        );
      }).toList(),
    );
  }

  Widget _buildCompactView(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: LabelType.values.map((type) {
          final isSelected = selectedTypes.contains(type);
          final count = typeCounts?[type] ?? 0;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              avatar: Icon(
                _getLabelTypeIcon(type),
                size: 16,
                color: isSelected ? Colors.white : Colors.grey[600],
              ),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getLabelTypeName(type)),
                  if (showCount && typeCounts != null) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Colors.white.withOpacity(0.2)
                            : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isSelected ? Colors.white : Colors.grey[600],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              backgroundColor: isSelected 
                  ? _getLabelTypeColor(type, true)
                  : Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onPressed: () => _toggleType(type),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Helper method for getting total count
  int get totalCount => typeCounts?.values.fold(0, (sum, count) => sum! + count) ?? 0;
}

// Extension method for label type utilities
extension LabelTypeUtils on LabelType {
  String get displayName {
    switch (this) {
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

  IconData get icon {
    switch (this) {
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

  Color get color {
    switch (this) {
      case LabelType.fgPallet:
        return Colors.blue;
      case LabelType.roll:
        return Colors.green;
      case LabelType.fgLocation:
        return Colors.orange;
      case LabelType.paperRollLocation:
        return Colors.purple;
    }
  }
}