import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/maintenance_reminder_controller.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';

class EditReminderFormPage extends StatefulWidget {
  final MaintenanceReminderModel reminder;
  const EditReminderFormPage({super.key, required this.reminder});

  @override
  State<EditReminderFormPage> createState() => _EditReminderFormPageState();
}

class _EditReminderFormPageState extends State<EditReminderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final MaintenanceReminderController _controller =
      MaintenanceReminderController();

  final List<String> _categories = [
    'Fuel',
    'Maintenance',
    'Car Wash',
    'Insurance',
    'Road Tax',
    'Installment',
    'Make Up',
  ];

  String? _selectedCategory;
  late TextEditingController _dateController;
  late TextEditingController _timeController;
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.reminder.maintenanceType;
    _dateController = TextEditingController(text: widget.reminder.dateExpired);
    _timeController = TextEditingController(text: widget.reminder.timeExpired);

    // Check if reminder is expired
    _checkIfExpired();
  }

  void _checkIfExpired() {
    try {
      final reminderDateTime = _parseFullDateTime(
        widget.reminder.dateExpired,
        widget.reminder.timeExpired,
      );

      if (reminderDateTime.isBefore(DateTime.now())) {
        setState(() {
          _isExpired = true;
        });
      }
    } catch (e) {
      print('Error checking expiration: $e');
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  DateTime _parseFullDateTime(String date, String time) {
    final dateTime = DateTime.parse(date);

    TimeOfDay timeOfDay;
    if (time.contains('AM') || time.contains('PM')) {
      final isPM = time.contains('PM');
      final timeWithoutPeriod = time.replaceAll(RegExp(r'[AP]M'), '').trim();
      final parts = timeWithoutPeriod.split(':');
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }

      timeOfDay = TimeOfDay(hour: hour, minute: minute);
    } else {
      final parts = time.split(':');
      timeOfDay = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
  }

  Future<void> _pickDate() async {
    if (_isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot edit expired reminders. Please delete and create a new one.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final currentDate =
        DateTime.tryParse(_dateController.text) ?? DateTime.now();
    final newDate = await showDatePicker(
      context: context,
      initialDate: currentDate.isBefore(DateTime.now())
          ? DateTime.now()
          : currentDate,
      firstDate: DateTime.now(), // Prevent past dates
      lastDate: DateTime(2100),
    );

    if (newDate != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(newDate);
        // Clear time if date changed to ensure time validation
        if (_timeController.text.isNotEmpty) {
          _validateAndClearTimeIfNeeded();
        }
      });
    }
  }

  void _validateAndClearTimeIfNeeded() {
    // Check if the currently selected time is now in the past with the new date
    if (_dateController.text.isNotEmpty && _timeController.text.isNotEmpty) {
      final selectedDate = DateTime.parse(_dateController.text);
      final timeParts = _timeController.text.split(':');

      // Handle both 24-hour and 12-hour formats
      TimeOfDay timeOfDay;
      if (_timeController.text.contains('AM') ||
          _timeController.text.contains('PM')) {
        final format = DateFormat.jm();
        final dateTime = format.parse(_timeController.text);
        timeOfDay = TimeOfDay(hour: dateTime.hour, minute: dateTime.minute);
      } else {
        timeOfDay = TimeOfDay(
          hour: int.parse(timeParts[0]),
          minute: int.parse(timeParts[1]),
        );
      }

      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      if (selectedDateTime.isBefore(DateTime.now())) {
        setState(() {
          _timeController.text = '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Time cleared as it would be in the past with the new date',
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    if (_isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot edit expired reminders. Please delete and create a new one.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date first')),
      );
      return;
    }

    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);

    if (picked != null) {
      // Check if the selected date and time combination is in the past
      final selectedDate = DateTime.parse(_dateController.text);
      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        picked.hour,
        picked.minute,
      );

      if (selectedDateTime.isBefore(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cannot select a past time')),
        );
        return;
      }

      setState(() {
        _timeController.text = picked.format(context);
      });
    }
  }

  TimeOfDay _parseTimeOfDay(String timeString) {
    // Remove any extra spaces
    timeString = timeString.trim();

    if (timeString.contains('AM') || timeString.contains('PM')) {
      // Handle 12-hour format (e.g., "12:44 PM")
      final isPM = timeString.contains('PM');
      final timeWithoutPeriod = timeString
          .replaceAll(RegExp(r'[AP]M'), '')
          .trim();
      final parts = timeWithoutPeriod.split(':');
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      // Convert to 24-hour format
      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }

      return TimeOfDay(hour: hour, minute: minute);
    } else {
      // Handle 24-hour format
      final parts = timeString.split(':');
      return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
  }

  String? _validateDateTime() {
    if (_dateController.text.isEmpty) {
      return 'Please select a date';
    }
    if (_timeController.text.isEmpty) {
      return 'Please select a time';
    }

    try {
      // Final validation before saving
      final selectedDate = DateTime.parse(_dateController.text);
      final timeOfDay = _parseTimeOfDay(_timeController.text);

      final selectedDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      if (selectedDateTime.isBefore(DateTime.now())) {
        return 'Selected date and time cannot be in the past';
      }

      return null;
    } catch (e) {
      return 'Invalid date or time format';
    }
  }

  Future<void> _saveChanges() async {
    if (_isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot edit expired reminders. Please delete and create a new one.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      final dateTimeError = _validateDateTime();
      if (dateTimeError != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(dateTimeError)));
        return;
      }

      try {
        await _controller.updateReminder(widget.reminder.id, {
          'maintenanceType': _selectedCategory,
          'dateExpired': _dateController.text,
          'timeExpired': _timeController.text,
        });

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder updated successfully.')),
        );
        Navigator.pop(context);
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final deleted = await _controller.confirmAndDeleteReminder(
      context,
      widget.reminder.id,
    );

    if (deleted && mounted) {
      Navigator.pop(context); // only pop the page if deletion actually happened
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isExpired ? 'View Expired Reminder' : 'Edit Reminder'),
        backgroundColor: _isExpired ? Colors.orange : Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Show warning if expired
              if (_isExpired) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This reminder has expired. You can only delete it.',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Text(
                "CATEGORY",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  enabled: !_isExpired,
                ),
                items: _categories
                    .map(
                      (item) =>
                          DropdownMenuItem(value: item, child: Text(item)),
                    )
                    .toList(),
                onChanged: _isExpired
                    ? null
                    : (val) => setState(() => _selectedCategory = val),
                validator: (val) => val == null || val.isEmpty
                    ? 'Please select a category'
                    : null,
              ),
              const SizedBox(height: 20),

              const Text(
                "DUE DATE & TIME",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              TextFormField(
                controller: _dateController,
                readOnly: true,
                enabled: !_isExpired,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.calendar_today),
                  filled: _isExpired,
                  fillColor: _isExpired ? Colors.grey.shade200 : null,
                ),
                onTap: _isExpired ? null : _pickDate,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Please select a date' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _timeController,
                readOnly: true,
                enabled: !_isExpired,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  suffixIcon: const Icon(Icons.access_time),
                  filled: _isExpired,
                  fillColor: _isExpired ? Colors.grey.shade200 : null,
                ),
                onTap: _isExpired ? null : _pickTime,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Please select a time' : null,
              ),
              const SizedBox(height: 30),

              if (!_isExpired)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _saveChanges,
                  child: const Text("Done", style: TextStyle(fontSize: 16)),
                ),

              if (!_isExpired) const SizedBox(height: 10),

              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: _confirmDelete,
                child: const Text("Delete", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
