import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangeSelector extends StatelessWidget {
  final DateTimeRange? selectedRange;
  final Function(DateTimeRange) onRangeSelected;
  final Function() onClearRange;

  const DateRangeSelector({
    super.key,
    this.selectedRange,
    required this.onRangeSelected,
    required this.onClearRange,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final initialRange = selectedRange ?? DateTimeRange(
                start: DateTime.now().subtract(const Duration(days: 7)),
                end: DateTime.now(),
              );
              
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
                initialDateRange: initialRange,
              );

              if (range != null) {
                onRangeSelected(range);
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    selectedRange != null
                        ? '${_formatDate(selectedRange!.start)} - ${_formatDate(selectedRange!.end)}'
                        : 'Select Date Range',
                    style: TextStyle(
                      color: selectedRange != null ? Colors.black : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (selectedRange != null)
          IconButton(
            icon: const Icon(Icons.clear),
            onPressed: onClearRange,
          ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}