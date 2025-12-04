import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/controller/maintenance_reminder_controller.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';

class EditReminderFormPage extends StatefulWidget {
  final MaintenanceReminderModel reminder;
  const EditReminderFormPage({super.key, required this.reminder});

  @override
  State<EditReminderFormPage> createState() => _EditReminderFormPageState();
}

class _EditReminderFormPageState extends State<EditReminderFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _controller = MaintenanceReminderController();

  final List<String> _categories = [
    'Fuel', 'Maintenance', 'Car Wash', 'Insurance', 'Road Tax', 'Installment', 'Make Up'
  ];

  late String _selectedCategory;
  late DateTime _dueDateTimeMalaysia;
  bool _isExpired = false;

  DateTime _toMalaysiaLocal(DateTime utcInstant) =>
      utcInstant.toUtc().add(const Duration(hours: 8));

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.reminder.maintenanceType;
    _dueDateTimeMalaysia = _toMalaysiaLocal(widget.reminder.dueDateTime);
    _isExpired = widget.reminder.dueDateTime.isBefore(DateTime.now().toUtc());
  }

  Future<void> _pickDate() async {
    if (_isExpired) return;

    final malaysiaNow = DateTime.now().toUtc().add(const Duration(hours: 8));
    final newDate = await showDatePicker(
      context: context,
      initialDate: _dueDateTimeMalaysia,
      firstDate: malaysiaNow,
      lastDate: DateTime(2100),
    );

    if (newDate != null) {
      setState(() {
        _dueDateTimeMalaysia = DateTime(
          newDate.year, newDate.month, newDate.day,
          _dueDateTimeMalaysia.hour, _dueDateTimeMalaysia.minute,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    if (_isExpired) return;

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_dueDateTimeMalaysia),
    );

    if (picked != null) {
      setState(() {
        _dueDateTimeMalaysia = DateTime(
          _dueDateTimeMalaysia.year, _dueDateTimeMalaysia.month, _dueDateTimeMalaysia.day,
          picked.hour, picked.minute,
        );
      });
    }
  }

  Future<void> _saveChanges() async {
    if (_isExpired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit expired reminders.')),
      );
      return;
    }

    final updated = MaintenanceReminderModel(
      id: widget.reminder.id,
      userId: widget.reminder.userId,
      maintenanceType: _selectedCategory,
      dueDateTime: _dueDateTimeMalaysia,
      status: 'active',
      createdAt: widget.reminder.createdAt,
    );

    await _controller.updateReminder(widget.reminder.id, updated);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reminder updated successfully.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('yyyy-MM-dd').format(_dueDateTimeMalaysia);
    final timeStr = TimeOfDay.fromDateTime(_dueDateTimeMalaysia).format(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isExpired ? 'View Expired Reminder' : 'Edit Reminder'),
        backgroundColor: _isExpired ? Colors.orange : Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (_isExpired)
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
                      Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This reminder has expired. You can only delete it.',
                          style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),

              const Text("CATEGORY", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: _isExpired ? null : (val) => setState(() => _selectedCategory = val!),
              ),

              const SizedBox(height: 20),

              const Text("DUE DATE & TIME", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),

              TextFormField(
                readOnly: true,
                enabled: !_isExpired,
                decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                controller: TextEditingController(text: dateStr),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),

              TextFormField(
                readOnly: true,
                enabled: !_isExpired,
                decoration: const InputDecoration(border: OutlineInputBorder(), suffixIcon: Icon(Icons.access_time)),
                controller: TextEditingController(text: timeStr),
                onTap: _pickTime,
              ),

              const SizedBox(height: 30),

              if (!_isExpired)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  onPressed: _saveChanges,
                  child: const Text("Done", style: TextStyle(fontSize: 16)),
                ),

              const SizedBox(height: 12),

              // Delete Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () async {
                  // CORRECT: Call the controller function that handles the dialog and returns a boolean.
                  final wasDeleted = await _controller.confirmAndDeleteReminder(context, widget.reminder.id);
                  // If it returns true, pop the edit page to go back to the list.
                  if (wasDeleted && mounted) {
                    Navigator.pop(context);
                  }
                },
                child: const Text("Delete", style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}