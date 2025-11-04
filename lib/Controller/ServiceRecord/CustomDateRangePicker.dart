import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomDateRangePicker extends StatefulWidget {
  final DateTimeRange? initialDateRange;

  const CustomDateRangePicker({super.key, this.initialDateRange});

  @override
  State<CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<CustomDateRangePicker> {
  late DateTime displayedMonth;
  DateTime? rangeStart;
  DateTime? rangeEnd;

  @override
  void initState() {
    super.initState();
    displayedMonth = widget.initialDateRange?.start ?? DateTime.now();
    rangeStart = widget.initialDateRange?.start;
    rangeEnd = widget.initialDateRange?.end;
  }

  void _onDayTapped(DateTime day) {
    setState(() {
      // First click: set start date
      if (rangeStart == null || (rangeStart != null && rangeEnd != null)) {
        rangeStart = day;
        rangeEnd = null;
      }
      // Second click: set end date
      else if (rangeStart != null && rangeEnd == null) {
        if (day.isBefore(rangeStart!)) {
          rangeEnd = rangeStart;
          rangeStart = day;
        } else {
          rangeEnd = day;
        }
      }
    });
  }

  bool _isWithinRange(DateTime day) {
    if (rangeStart == null || rangeEnd == null) return false;
    return (day.isAfter(rangeStart!) || day.isAtSameMomentAs(rangeStart!)) &&
        (day.isBefore(rangeEnd!) || day.isAtSameMomentAs(rangeEnd!));
  }

  @override
  Widget build(BuildContext context) {
    final year = displayedMonth.year;
    final month = displayedMonth.month;
    final firstDay = DateTime(year, month, 1);
    final daysInMonth = DateUtils.getDaysInMonth(year, month);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Select Date Range',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 320, // ✅ Fix layout issue
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                    () => displayedMonth = DateTime(year, month - 1, 1),
                  ),
                ),
                Text(
                  DateFormat.yMMMM().format(displayedMonth),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                    () => displayedMonth = DateTime(year, month + 1, 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(child: _buildCalendarGrid(firstDay, daysInMonth)),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: (rangeStart != null)
              ? () {
                  // ✅ Allow single-day OR range filter
                  final range = DateTimeRange(
                    start: rangeStart!,
                    end: rangeEnd ?? rangeStart!,
                  );
                  Navigator.pop(context, range);
                }
              : null,
          child: const Text(
            'Apply',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(DateTime firstDay, int daysInMonth) {
    final weekdayOffset = firstDay.weekday - 1;
    final totalCells = weekdayOffset + daysInMonth;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < weekdayOffset) return const SizedBox.shrink();

        final day = index - weekdayOffset + 1;
        final date = DateTime(firstDay.year, firstDay.month, day);

        final isSelected = date == rangeStart || date == rangeEnd;
        final isInRange = _isWithinRange(date);

        return GestureDetector(
          onTap: () => _onDayTapped(date),
          child: Container(
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.blue
                  : isInRange
                  ? Colors.blue.shade100
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text(
              '$day',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        );
      },
    );
  }
}
