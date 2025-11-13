import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ridefix/controller/maintenance_reminder_controller.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';

class SetReminderView extends StatefulWidget {
  const SetReminderView({super.key});

  @override
  State<SetReminderView> createState() => _SetReminderViewState();
}

class _SetReminderViewState extends State<SetReminderView> {
  final _controller = MaintenanceReminderController();

  final List<String> _categories = [
    'Fuel', 'Maintenance', 'Car Wash', 'Insurance', 'Road Tax', 'Installment', 'Make Up'
  ];

  String? _selectedCategory;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now, // Prevent past dates
      lastDate: DateTime(2100),
    );

    if (picked != null) setState(() => _selectedDate = picked);
  }


  Future<void> _selectTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: now,
    );

    if (picked != null) {
      // If date is today, prevent selecting a past time
      if (_selectedDate != null) {
        final today = DateTime.now();
        final selectedDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          picked.hour,
          picked.minute,
        );

        if (selectedDateTime.isBefore(today)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot select a past time')),
          );
          return; // Don't set the time
        }
      }

      setState(() => _selectedTime = picked);
    }
  }


  Future<void> _saveReminder() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_selectedCategory == null || _selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final reminder = MaintenanceReminderModel(
      id: '',
      userId: user.uid,
      maintenanceType: _selectedCategory!,
      dateExpired: DateFormat('yyyy-MM-dd').format(_selectedDate!),
      timeExpired: _selectedTime!.format(context),
      status: 'active',
    );



    await _controller.addReminder(reminder);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder saved successfully!')),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Set Reminders')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("CATEGORY"),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text("Select category"),
              items: _categories
                  .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
            ),
            const SizedBox(height: 16),
            const Text("DUE DATE & TIME"),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(_selectedDate == null
                  ? "Date"
                  : DateFormat('yyyy-MM-dd').format(_selectedDate!)),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _selectTime,
              icon: const Icon(Icons.access_time),
              label: Text(_selectedTime == null
                  ? "Time"
                  : _selectedTime!.format(context)),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveReminder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text("Done"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
