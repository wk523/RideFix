import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart'; //
import '../../controller/parking_controller.dart';
import '../../model/parking_model.dart';
import 'package:ridefix/View/parking/parking_details_card.dart';

class ParkingTrackerPage extends StatefulWidget {
  final bool showAddForm;

  const ParkingTrackerPage({Key? key, this.showAddForm = false}) : super(key: key);

  @override
  State<ParkingTrackerPage> createState() => _ParkingTrackerPageState();
}

class _ParkingTrackerPageState extends State<ParkingTrackerPage> {
  late final ParkingController _controller;

  LatLng? _currentLatLng;

  final _formKey = GlobalKey<FormState>();

  final TextEditingController _floor_controller = TextEditingController();
  final TextEditingController _lot_controller = TextEditingController();
  final TextEditingController _latitude_controller = TextEditingController();
  final TextEditingController _longitude_controller = TextEditingController();

  DateTime? _selectedDate; // Malaysia local date
  TimeOfDay? _selectedTime; // Malaysia local time

  @override
  void initState() {
    super.initState();
    _controller = ParkingController();
    _handleLocationPermission();
  }

  @override
  void dispose() {
    _floor_controller.dispose();
    _lot_controller.dispose();
    _latitude_controller.dispose();
    _longitude_controller.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleLocationPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services disabled')));
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        return;
      }
    }

    if (permission == LocationPermission.deniedForever && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permissions permanently denied')));
      return;
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      setState(() {
        _currentLatLng = LatLng(pos.latitude, pos.longitude);
        _latitude_controller.text = pos.latitude.toString();
        _longitude_controller.text = pos.longitude.toString();
      });
      _controller.moveCamera(_currentLatLng!);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _pickDateTime() async {
    final DateTime nowMalaysia = DateTime.now().toUtc().add(const Duration(hours: 8));

    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? nowMalaysia,
      firstDate: nowMalaysia,
      lastDate: nowMalaysia.add(const Duration(days: 365)),
    );
    if (pickedDate == null) return;

    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.fromDateTime(nowMalaysia.add(const Duration(minutes: 1))),
    );
    if (pickedTime == null) return;

    setState(() {
      _selectedDate = pickedDate;
      _selectedTime = pickedTime;
    });
  }

  String _selectedDateTimeText() {
    if (_selectedDate == null || _selectedTime == null) return 'Select reminder date & time';
    final dt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
    // Use DateFormat for a clean, user-friendly string
    return DateFormat('yyyy-MM-dd  hh:mm a').format(dt);
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please choose a reminder date & time')));
      return;
    }

    final selectedMalaysia = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    // Truncate current time to the minute for fair comparison
    final nowMalaysia = DateTime.now().toUtc().add(const Duration(hours: 8));
    final truncatedNow = DateTime(nowMalaysia.year, nowMalaysia.month, nowMalaysia.day, nowMalaysia.hour, nowMalaysia.minute);

    // Check if the selected minute is after the current minute
    if (!selectedMalaysia.isAfter(truncatedNow)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot select a past or current minute. Please select a future time.')));
      return;
    }

    final parking = _controller.createParkingFromForm(
      floor: _floor_controller.text.trim(),
      lot: _lot_controller.text.trim(),
      latitude: double.tryParse(_latitude_controller.text.trim()) ?? 0.0,
      longitude: double.tryParse(_longitude_controller.text.trim()) ?? 0.0,
      malaysiaExpired: selectedMalaysia,
    );

    _controller.addParking(context, parking);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parking Tracker'), centerTitle: true),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(
                flex: 3,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20)),
                  child: StreamBuilder<List<Parking>>(
                    stream: _controller.allParkingsStream,
                    builder: (context, snapshot) {
                      final parkings = snapshot.data ?? [];
                      final lastParking =
                      parkings.isNotEmpty ? parkings.first : null;

                      return GoogleMap(
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        initialCameraPosition: CameraPosition(
                          target: _currentLatLng ??
                              (lastParking != null
                                  ? LatLng(lastParking.latitude,
                                  lastParking.longitude)
                                  : const LatLng(3.1390, 101.6869)),
                          zoom: 15,
                        ),
                        markers: {
                          if (lastParking != null)
                            Marker(
                              markerId: const MarkerId('last_parking'),
                              position:
                              LatLng(lastParking.latitude, lastParking.longitude),
                              infoWindow: InfoWindow(
                                title: 'Last Parking',
                                snippet:
                                '${lastParking.parkingFloor}/${lastParking.lotNum}',
                              ),
                            ),
                        },
                        onMapCreated: (mapCtrl) {
                          _controller.setMapController(mapCtrl);
                          _getCurrentLocation();
                        },
                      );
                    },
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: _buildFormSection(),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _getCurrentLocation,
        child: const Icon(Icons.my_location),
      ),
    );
  }

  Widget _buildFormSection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _floor_controller,
                decoration: const InputDecoration(labelText: 'Parking Floor', prefixIcon: Icon(Icons.layers)),
                validator: (v) => v == null || v.isEmpty ? 'Please enter the floor' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _lot_controller,
                decoration: const InputDecoration(labelText: 'Lot Number', prefixIcon: Icon(Icons.local_parking)),
                validator: (v) => v == null || v.isEmpty ? 'Please enter lot' : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latitude_controller,
                      decoration: const InputDecoration(labelText: 'Latitude', prefixIcon: Icon(Icons.gps_fixed)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v == null || v.isEmpty ? 'Enter lat' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _longitude_controller,
                      decoration: const InputDecoration(labelText: 'Longitude', prefixIcon: Icon(Icons.gps_fixed)),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => v == null || v.isEmpty ? 'Enter lng' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDateTime,
                icon: const Icon(Icons.timer_outlined),
                label: Text(_selectedDateTimeText(), style: const TextStyle(fontSize: 15)),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _submitForm,
                icon: const Icon(Icons.save),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14.0),
                  child: Text('Save Location', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
