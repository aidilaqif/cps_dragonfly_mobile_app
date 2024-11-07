import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangeSelector extends StatefulWidget {
  final DateTimeRange? selectedRange;
  final Function(DateTimeRange) onRangeSelected;
  final Function() onClearRange;
  final DateTime? minDate;
  final DateTime? maxDate;
  final bool showQuickSelect;
  final String? helperText;
  final bool showTime;

  const DateRangeSelector({
    super.key,
    this.selectedRange,
    required this.onRangeSelected,
    required this.onClearRange,
    this.minDate,
    this.maxDate,
    this.showQuickSelect = true,
    this.helperText,
    this.showTime = false,
  });

  @override
  State<DateRangeSelector> createState() => _DateRangeSelectorState();
}

class _DateRangeSelectorState extends State<DateRangeSelector> {
  final List<QuickDateRange> _quickRanges = [
    QuickDateRange('Today', () {
      final now = DateTime.now();
      return DateTimeRange(
        start: DateTime(now.year, now.month, now.day),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    }),
    QuickDateRange('Yesterday', () {
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(days: 1));
      return DateTimeRange(
        start: DateTime(yesterday.year, yesterday.month, yesterday.day),
        end: DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59),
      );
    }),
    QuickDateRange('Last 7 Days', () {
      final now = DateTime.now();
      return DateTimeRange(
        start: DateTime(now.year, now.month, now.day - 6),
        end: DateTime(now.year, now.month, now.day, 23, 59, 59),
      );
    }),
    QuickDateRange('This Month', () {
      final now = DateTime.now();
      return DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: DateTime(now.year, now.month + 1, 0, 23, 59, 59),
      );
    }),
    QuickDateRange('Last Month', () {
      final now = DateTime.now();
      return DateTimeRange(
        start: DateTime(now.year, now.month - 1, 1),
        end: DateTime(now.year, now.month, 0, 23, 59, 59),
      );
    }),
  ];

  String _getDisplayText() {
    if (widget.selectedRange == null) return 'Select Date Range';

    final startDate = widget.selectedRange!.start;
    final endDate = widget.selectedRange!.end;
    
    final formatter = DateFormat(widget.showTime ? 'dd/MM/yyyy HH:mm' : 'dd/MM/yyyy');
    
    if (startDate == endDate) {
      return formatter.format(startDate);
    } else {
      return '${formatter.format(startDate)} - ${formatter.format(endDate)}';
    }
  }

  Future<void> _showDateRangePicker() async {
    final initialRange = widget.selectedRange ?? DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      end: DateTime.now(),
    );

    final range = await showDateRangePicker(
      context: context,
      firstDate: widget.minDate ?? DateTime(2020),
      lastDate: widget.maxDate ?? DateTime.now(),
      initialDateRange: initialRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      DateTime start = range.start;
      DateTime end = range.end;

      if (widget.showTime) {
        // Show time picker for start time
        final startTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(start),
        );
        if (startTime != null) {
          start = DateTime(
            start.year,
            start.month,
            start.day,
            startTime.hour,
            startTime.minute,
          );
        }

        // Show time picker for end time
        final endTime = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(end),
        );
        if (endTime != null) {
          end = DateTime(
            end.year,
            end.month,
            end.day,
            endTime.hour,
            endTime.minute,
          );
        }
      } else {
        // If no time selection, set end time to end of day
        end = DateTime(
          end.year,
          end.month,
          end.day,
          23,
          59,
          59,
        );
      }

      widget.onRangeSelected(DateTimeRange(start: start, end: end));
    }
  }

  void _showQuickSelectMenu() {
    final RenderBox button = context.findRenderObject() as RenderBox;
    final Offset offset = button.localToGlobal(Offset.zero);

    showMenu<DateTimeRange>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy + button.size.height,
        offset.dx + button.size.width,
        offset.dy + button.size.height,
      ),
      items: _quickRanges.map((range) {
        return PopupMenuItem<DateTimeRange>(
          value: range.getRange(),
          child: Text(range.label),
        );
      }).toList(),
    ).then((value) {
      if (value != null) {
        widget.onRangeSelected(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: _showDateRangePicker,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: widget.selectedRange != null
                          ? Theme.of(context).primaryColor
                          : Colors.grey[300]!,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: widget.selectedRange != null
                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                        : Colors.transparent,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: widget.selectedRange != null
                            ? Theme.of(context).primaryColor
                            : Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getDisplayText(),
                          style: TextStyle(
                            color: widget.selectedRange != null
                                ? Colors.black
                                : Colors.grey[600],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.showQuickSelect)
                        IconButton(
                          icon: const Icon(Icons.arrow_drop_down),
                          onPressed: _showQuickSelectMenu,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          color: Colors.grey[600],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.selectedRange != null) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: widget.onClearRange,
                color: Theme.of(context).primaryColor,
                tooltip: 'Clear date range',
              ),
            ],
          ],
        ),
        if (widget.helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            widget.helperText!,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class QuickDateRange {
  final String label;
  final DateTimeRange Function() getRange;

  QuickDateRange(this.label, this.getRange);
}