import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ridefix/controller/maintenance_reminder_controller.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceController.dart'; // Assuming this is where vehicleDataService lives
import 'package:ridefix/Model/vehicle_maintenance_model.dart';

class SetReminderView extends StatefulWidget {
  const SetReminderView({super.key});

  @override
  State<SetReminderView> createState() => _SetReminderViewState();
}

class _SetReminderViewState extends State<SetReminderView> {
  final _controller = MaintenanceReminderController();

  // State for the form fields
  final List<String> _categories = [
    'Fuel',
    'Maintenance',
    'Car Wash',
    'Insurance',
    'Road Tax',
    'Installment',
    'Make Up',
  ];
  String? _selectedVehicleId;
  String? _selectedCategory;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now,
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? now,
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
        final nowDateTime = DateTime.now();
        final truncatedSelected = DateTime(
          selectedDateTime.year,
          selectedDateTime.month,
          selectedDateTime.day,
          selectedDateTime.hour,
          selectedDateTime.minute,
        );
        final truncatedNow = DateTime(
          nowDateTime.year,
          nowDateTime.month,
          nowDateTime.day,
          nowDateTime.hour,
          nowDateTime.minute,
        );
        if (truncatedSelected.isBefore(truncatedNow)) {
          if (mounted)
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

    if (_selectedVehicleId == null ||
        _selectedCategory == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    final malaysiaDueDateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final reminder = MaintenanceReminderModel(
      userId: user.uid,
      vehicleId: _selectedVehicleId, // Pass the selected vehicle ID
      maintenanceType: _selectedCategory!,
      dueDateTime: malaysiaDueDateTime,
      createdAt: DateTime.now(),
      status: 'active',
    );

    await _controller.addReminder(reminder);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reminder saved successfully!')),
      );
      Navigator.pop(context);
    }
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
            // --- NEW VEHICLE DROPDOWN ---
            const Text(
              "VEHICLE",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            StreamBuilder<List<Vehicle>>(
              stream: vehicleDataService.vehiclesStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Text('Loading vehicles...');
                }
                final vehicles = snapshot.data!;
                return DropdownButtonFormField<String>(
                  value: _selectedVehicleId,
                  hint: const Text("Select vehicle"),
                  items: vehicles.map((vehicle) {
                    return DropdownMenuItem(
                      value: vehicle.vehicleId,
                      child: Text(
                        '${vehicle.brand} ${vehicle.model} (${vehicle.plateNumber})',
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedVehicleId = val),
                  validator: (value) =>
                      value == null ? 'Please select a vehicle' : null,
                );
              },
            ),
            const SizedBox(height: 16),

            const Text(
              "CATEGORY",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              hint: const Text("Select category"),
              items: _categories
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: (val) => setState(() => _selectedCategory = val),
              validator: (value) =>
                  value == null ? 'Please select a category' : null,
            ),
            const SizedBox(height: 16),

            const Text(
              "DUE DATE & TIME",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _selectDate,
              icon: const Icon(Icons.calendar_today),
              label: Text(
                _selectedDate == null
                    ? "Date"
                    : DateFormat('yyyy-MM-dd').format(_selectedDate!),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _selectTime,
              icon: const Icon(Icons.access_time),
              label: Text(
                _selectedTime == null ? "Time" : _selectedTime!.format(context),
              ),
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
