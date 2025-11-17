import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- MOCK/PLACEHOLDER DATA STRUCTURES AND SERVICES (FOR COMPILATION ONLY) ---
// These classes ensure the UI references to Vehicle, DataService, etc., compile.

class Vehicle {
  final String brand;
  final String model;
  final String plateNumber;
  final String vehicleId;
  final String? mileage;

  Vehicle({
    required this.brand,
    required this.model,
    required this.plateNumber,
    required this.vehicleId,
    required this.mileage,
  });
}

class VehicleDataService {
  Future<List<Vehicle>> readVehicleData() async => [
    Vehicle(
      brand: 'Honda',
      model: 'Civic',
      plateNumber: 'XXX 1234',
      vehicleId: 'VEC001',
      mileage: '240919',
    ),
    Vehicle(
      brand: 'Toyota',
      model: 'Supra',
      plateNumber: 'YYY 5678',
      vehicleId: 'VEC002',
      mileage: '10050',
    ),
  ];
  Future<void> updateVehicleMileage(
    String vehicleId,
    double newMileage,
  ) async {}
}

class FuelEntryDatabase {
  Future<String> uploadReceiptImage(Uint8List imageBytes) async => '';
  Future<void> addFuelEntry({
    required String uid,
    required String vehicleId,
    required double amount,
    required double volumeL,
    required double pricePerLiter,
    required String fuelType,
    required String station,
    required double mileage,
    required String date,
    required bool isFullTank,
    String? imgURL,
  }) async {}
}

// --- MAIN WIDGET ---

class AddFuelEntryPage extends StatefulWidget {
  final dynamic userDoc;
  const AddFuelEntryPage({super.key, this.userDoc});

  @override
  State<AddFuelEntryPage> createState() => _AddFuelEntryPageState();
}

class _AddFuelEntryPageState extends State<AddFuelEntryPage> {
  // --- Controllers for Form Fields ---
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stationController = TextEditingController();
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  // --- State Variables (Minimal/Dummy for UI rendering) ---
  String _selectedFuelType = 'Petrol RON95';
  bool _isFullTank = true;
  DateTime? _selectedDate = DateTime.now();
  Uint8List? _selectedImageBytes;
  bool _isSaving = false;

  final List<Vehicle> _vehicleList = [];
  Vehicle? _selectedVehicle;

  final List<String> _fuelTypes = [
    'Petrol RON95',
    'Petrol RON97',
    'Diesel',
    'Premium Diesel',
    'EV Charge',
    'Others',
  ];

  // --- DUMMY/PLACEHOLDER METHODS (NO LOGIC) ---
  @override
  void initState() {
    super.initState();
    // Initialize date placeholder
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
    // Populate mock vehicle list for dropdown
    _vehicleList.addAll([
      Vehicle(
        brand: 'Honda',
        model: 'Civic',
        plateNumber: 'XXX 1234',
        vehicleId: 'VEC001',
        mileage: '240919',
      ),
    ]);
    _selectedVehicle = _vehicleList.first;
    _mileageController.text = '240919';
  }

  @override
  void dispose() {
    _amountController.dispose();
    _volumeController.dispose();
    _priceController.dispose();
    _stationController.dispose();
    _mileageController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _calculatePrice() {}
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _pickOrCaptureImage() async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Upload from Gallery'),
              onTap: () async {
                final XFile? image = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (image != null) {
                  final bytes = await image
                      .readAsBytes(); // ✅ wait outside setState
                  setState(() {
                    _selectedImageBytes = bytes;
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () async {
                final XFile? photo = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (photo != null) {
                  final bytes = await photo
                      .readAsBytes(); // ✅ wait outside setState
                  setState(() {
                    _selectedImageBytes = bytes;
                  });
                }
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _saveRecord() {}

  // --- UI HELPER METHODS FOR CONSISTENT STYLE ---

  // Removed _buildHeader as we are now using labelText

  Widget _buildDateButton(
    String text, {
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // --- BUILD METHOD (THE CORE UI) ---

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              'Add Fuel Entry',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.blue,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Column(
            children: [
              // Scrollable content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // --- Vehicle Dropdown ---
                      DropdownButtonFormField<Vehicle>(
                        value: _selectedVehicle,
                        decoration: const InputDecoration(
                          labelText: 'Select Vehicle',
                          border: OutlineInputBorder(),
                        ),
                        items: _vehicleList.map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text(
                              '${v.brand} ${v.model} (${v.plateNumber})',
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          // Dummy update
                          setState(() => _selectedVehicle = value);
                        },
                      ),
                      const SizedBox(height: 16),

                      // --- ODOMETER / MILEAGE ---
                      TextFormField(
                        controller: _mileageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Current Mileage (km)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- AMOUNT PAID ---
                      TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount (RM)',
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d{0,2}'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- VOLUME & PRICE ---
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _volumeController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: const InputDecoration(
                                labelText: 'Volume (L)',
                                border: OutlineInputBorder(),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,3}'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Price Per Liter (RM)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // --- FUEL TYPE (Dropdown) ---
                      DropdownButtonFormField<String>(
                        value: _selectedFuelType,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _fuelTypes.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) =>
                            setState(() => _selectedFuelType = value!),
                      ),
                      const SizedBox(height: 10),

                      // --- FULL TANK (Checkbox) ---
                      InkWell(
                        onTap: () => setState(() => _isFullTank = !_isFullTank),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Checkbox(
                              value: _isFullTank,
                              onChanged: (val) =>
                                  setState(() => _isFullTank = val ?? false),
                              activeColor: Colors.blue,
                            ),
                            const Text(
                              'Full Tank',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- FUEL STATION ---
                      TextFormField(
                        controller: _stationController,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Station (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // --- Date ---
                      TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        onTap: _pickDate,
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// Add Photo
                      OutlinedButton.icon(
                        onPressed: _pickOrCaptureImage,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(
                          _selectedImageBytes == null
                              ? 'Add Photo'
                              : 'Change Photo',
                        ),
                      ),
                      if (_selectedImageBytes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: FutureBuilder<ui.Image>(
                              future: decodeImageFromList(_selectedImageBytes!),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return const SizedBox(
                                    height: 180,
                                    child: Center(
                                      child: CircularProgressIndicator(),
                                    ),
                                  );
                                }
                                final image = snapshot.data!;
                                final aspectRatio = image.width / image.height;
                                return AspectRatio(
                                  aspectRatio: aspectRatio,
                                  child: Image.memory(
                                    _selectedImageBytes!,
                                    fit: BoxFit.contain,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // --- Fixed Save button ---
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveRecord,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blue,
                      elevation: 5,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Done',
                            style: TextStyle(fontSize: 18, color: Colors.white),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),

        /// Loading overlay
        if (_isSaving)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
