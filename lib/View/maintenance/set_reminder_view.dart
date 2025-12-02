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
      firstDate: now,
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
      if (_selectedDate != null) {
        final selectedDateTime = DateTime(
          _selectedDate!.year,
          _selectedDate!.month,
          _selectedDate!.day,
          picked.hour,
          picked.minute,
        );

        // 检查时间（Malaysia 时间）
        final nowMalaysia = DateTime.now().toUtc().add(const Duration(hours: 8));
        final malaysiaDt = selectedDateTime.add(const Duration(hours: 8));

        if (malaysiaDt.isBefore(nowMalaysia)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot select a past time')),
          );
          return;
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

    // 用户选择的时间（Malaysia UTC+8）
    final selectedHour = _selectedTime!.hour;
    final selectedMinute = _selectedTime!.minute;

    // 创建 Malaysia 时间
    final malaysiaDt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      selectedHour,
      selectedMinute,
    );


    final utcDateTime = malaysiaDt.subtract(const Duration(hours: 8));

    ;

    // 再次检查时间
    final nowMalaysia = DateTime.now().toUtc().add(const Duration(hours: 8));
    if (malaysiaDt.isBefore(nowMalaysia)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot select a past time')),
      );
      return;
    }

    final reminder = MaintenanceReminderModel(
      userId: user.uid,
      maintenanceType: _selectedCategory!,
      dueDateTime: utcDateTime,
      createdAt: DateTime.now().toUtc(),
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