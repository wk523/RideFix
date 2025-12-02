import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:ridefix/controller/parking_controller.dart';
import 'package:ridefix/model/parking_model.dart';

class EditParkingFormPage extends StatefulWidget {
  final Parking parking;

  const EditParkingFormPage({super.key, required this.parking});

  @override
  State<EditParkingFormPage> createState() => _EditParkingFormPageState();
}

class _EditParkingFormPageState extends State<EditParkingFormPage> {
  final _formKey = GlobalKey<FormState>();
  final ParkingController _controller = ParkingController();

  late TextEditingController _floorController;
  late TextEditingController _lotController;
  late TextEditingController _latController;
  late TextEditingController _lngController;

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  LatLng? _currentLatLng;

  @override
  void initState() {
    super.initState();

    _floorController = TextEditingController(text: widget.parking.parkingFloor);
    _lotController = TextEditingController(text: widget.parking.lotNum);
    _latController = TextEditingController(text: widget.parking.latitude.toString());
    _lngController = TextEditingController(text: widget.parking.longitude.toString());

    // expiredTimeUtc → Malaysia local
    final malaysia = widget.parking.expiredTimeUtc.toUtc().add(const Duration(hours: 8));
    _selectedDate = DateTime(malaysia.year, malaysia.month, malaysia.day);
    _selectedTime = TimeOfDay(hour: malaysia.hour, minute: malaysia.minute);

    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
      });
    } catch (_) {}
  }

  Future<void> _pickDateTime() async {
    final MalaysiaNow = DateTime.now().toUtc().add(const Duration(hours: 8));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? MalaysiaNow,
      firstDate: MalaysiaNow,
      lastDate: MalaysiaNow.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  String _selectedDateTimeText() {
    if (_selectedDate == null || _selectedTime == null) return "Select reminder date & time";
    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    return DateFormat('yyyy-MM-dd  hh:mm a').format(dt);
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a reminder time")),
      );
      return;
    }

    final malaysiaSelected = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final nowMalaysia = DateTime.now().toUtc().add(const Duration(hours: 8));
    final truncatedNow = DateTime(
      nowMalaysia.year,
      nowMalaysia.month,
      nowMalaysia.day,
      nowMalaysia.hour,
      nowMalaysia.minute,
    );

    if (!malaysiaSelected.isAfter(truncatedNow)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selected time must be in the future")),
      );
      return;
    }

    // Convert Malaysia → UTC
    final utcTime = malaysiaSelected.toUtc().subtract(const Duration(hours: 0));

    try {
      final updated = Parking(
        id: widget.parking.id,
        parkingFloor: _floorController.text.trim(),
        lotNum: _lotController.text.trim(),
        latitude: double.tryParse(_latController.text) ?? widget.parking.latitude,
        longitude: double.tryParse(_lngController.text) ?? widget.parking.longitude,
        expiredTimeUtc: utcTime,
      );

      await _controller.updateParking(updated);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Parking updated"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  void dispose() {
    _floorController.dispose();
    _lotController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Parking"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _floorController,
                decoration: const InputDecoration(
                  labelText: 'Parking Floor',
                  prefixIcon: Icon(Icons.layers),
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter floor" : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _lotController,
                decoration: const InputDecoration(
                  labelText: 'Lot Number',
                  prefixIcon: Icon(Icons.local_parking),
                ),
                validator: (v) => v == null || v.isEmpty ? "Enter lot" : null,
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latController,
                      decoration: const InputDecoration(
                        labelText: 'Latitude',
                        prefixIcon: Icon(Icons.gps_fixed),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v == null || v.isEmpty ? "Enter latitude" : null,
                    ),
                  ),
                  const SizedBox(width: 8),

                  Expanded(
                    child: TextFormField(
                      controller: _lngController,
                      decoration: const InputDecoration(
                        labelText: 'Longitude',
                        prefixIcon: Icon(Icons.gps_fixed),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v == null || v.isEmpty ? "Enter longitude" : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.timer_outlined),
                label: Text(
                  _selectedDateTimeText(),
                  style: const TextStyle(fontSize: 15),
                ),
              ),

              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.save),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text("Save Changes", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
