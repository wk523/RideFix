// import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';

class AddFuelEntryPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const AddFuelEntryPage({super.key, required this.userDoc});

  @override
  State<AddFuelEntryPage> createState() => _AddFuelEntryPageState();
}

class FuelDataService {
  final storageRef = FirebaseStorage.instance.ref();

  Future<String> uploadFuelImage(Uint8List bytes) async {
    final path = "fuel_images/${DateTime.now().millisecondsSinceEpoch}.jpg";
    final ref = storageRef.child(path);
    await ref.putData(bytes);
    return await ref.getDownloadURL();
  }
}

class _AddFuelEntryPageState extends State<AddFuelEntryPage> {
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _volumeController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _stationController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  Vehicle? _selectedVehicle;
  List<Vehicle> _vehicleList = [];

  final VehicleDataService _vehicleService = VehicleDataService();

  String _selectedFuelType = "RON95";
  bool _isFullTank = false;
  Uint8List? _selectedImageBytes;

  DateTime? _selectedDate = DateTime.now();
  bool _isSaving = false;

  final _fuelTypes = ["RON95", "RON97", "DIESEL", "EV CHARGE", "OTHER"];

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _dateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());
  }

  /// ------------------------------------------------------------
  /// READ VEHICLE LIST (your required version)
  /// ------------------------------------------------------------
  Future<void> _loadVehicles() async {
    final list = await _vehicleService.readVehicleData();
    setState(() => _vehicleList = list);
  }

  /// ------------------------------------------------------------
  /// DATE PICKER
  /// ------------------------------------------------------------
  Future<void> _pickDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat("yyyy-MM-dd").format(picked);
      });
    }
  }

  /// ------------------------------------------------------------
  /// SAFE MILEAGE PARSER
  /// ------------------------------------------------------------
  double _safeMileageParse(String? value) {
    if (value == null) return 0;
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return double.tryParse(cleaned) ?? 0;
  }

  /// ------------------------------------------------------------
  /// Success Dialog
  /// ------------------------------------------------------------

  Future<void> _showSuccessDialog(double fuelEfficiency) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text("Fuel Entry Saved"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, size: 50, color: Colors.green),
              const SizedBox(height: 12),
              Text(
                "Fuel Efficiency:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                "${fuelEfficiency.toStringAsFixed(2)} km/L",
                style: TextStyle(fontSize: 20, color: Colors.blue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  /// ------------------------------------------------------------
  /// Get Last Fuel Mileage
  /// ------------------------------------------------------------
  Future<double> _getLastFuelMileage() async {
    final query = await FirebaseFirestore.instance
        .collection('fuel_records')
        .where('vehicleId', isEqualTo: _selectedVehicle!.vehicleId)
        .orderBy('mileage', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return 0;

    return (query.docs.first.data()['mileage'] ?? 0).toDouble();
  }

  /// ------------------------------------------------------------
  /// AUTO CALCULATE PRICE PER LITER
  /// ------------------------------------------------------------
  void _autoCalculatePricePerLiter() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final volume = double.tryParse(_volumeController.text) ?? 0;

    if (amount > 0 && volume > 0) {
      final pricePerLiter = amount / volume;
      _priceController.text = pricePerLiter.toStringAsFixed(2);
    } else {
      _priceController.text = "";
    }
  }

  /// ------------------------------------------------------------
  /// SAVE RECORD
  /// ------------------------------------------------------------
  Future<void> _saveRecord() async {
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a vehicle.")));
      return;
    }

    // --- PREVENT FUTURE DATE ---
    final inputDate = DateFormat("yyyy-MM-dd").parse(_dateController.text);
    if (inputDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Date cannot be in the future.")),
      );
      return;
    }

    final mileageEntered = _safeMileageParse(_mileageController.text);
    final currentMileage = (_selectedVehicle!.mileage);

    if (mileageEntered < currentMileage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Mileage cannot be lower than current mileage."),
        ),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    final volume = double.tryParse(_volumeController.text) ?? 0;

    if (amount <= 0 || volume <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Please fill in amount & volume.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    // --- IMAGE UPLOAD ---
    String? imgUrl;
    if (_selectedImageBytes != null) {
      imgUrl = await FuelDataService().uploadFuelImage(_selectedImageBytes!);
    }

    // --- GET PREVIOUS MILAGE FOR FUEL EFFICIENCY ---
    final lastMileage = await _getLastFuelMileage();
    double fuelEfficiency = 0;

    if (lastMileage > 0 && mileageEntered > lastMileage) {
      final distance = mileageEntered - lastMileage;
      fuelEfficiency = distance / volume;
    }

    // --- SAVE INTO FIRESTORE ---
    final data = {
      "uid": FirebaseAuth.instance.currentUser!.uid,
      "vehicleId": _selectedVehicle!.vehicleId,
      "mileage": mileageEntered,
      "amount": amount,
      "volume": volume,
      "pricePerLiter": amount / volume,
      "fuelType": _selectedFuelType,
      "isFullTank": _isFullTank,
      "station": _stationController.text,
      "date": _dateController.text,
      "imageUrl": imgUrl ?? "",
      "fuelEfficiency": fuelEfficiency, // 🔥 NEW
      "createdAt": DateTime.now(),
    };

    await FirebaseFirestore.instance.collection("fuel_records").add(data);

    // --- UPDATE VEHICLE MILEAGE ---
    if (mileageEntered > currentMileage) {
      await FirebaseFirestore.instance
          .collection("vehicles")
          .doc(_selectedVehicle!.vehicleId)
          .update({"mileage": mileageEntered.toString()});
    }

    setState(() => _isSaving = false);

    // --- SHOW POPUP ---
    await _showSuccessDialog(fuelEfficiency);

    if (mounted) Navigator.pop(context, true);
  }

  /// ------------------------------------------------------------
  /// UI
  /// ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              'Add Fuel Entry',
              style: TextStyle(color: Colors.white),
            ),
            centerTitle: true,
            backgroundColor: Colors.blue,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),

          //--------------------------------
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      /// VEHICLE DROPDOWN
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
                              "${v.brand} ${v.model} (${v.plateNumber})",
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedVehicle = value;

                            // Auto fill mileage with the selected vehicle’s current mileage
                            if (value != null) {
                              _mileageController.text = value.mileage
                                  .toString();
                            }
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      /// MILEAGE
                      TextFormField(
                        controller: _mileageController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],

                        decoration: InputDecoration(
                          labelText: 'Current Mileage (km)',
                          hintText: _selectedVehicle != null
                              ? 'Current: ${_selectedVehicle!.mileage} km'
                              : 'Enter mileage',
                          suffixText: 'km',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),

                        onTap: () {
                          // Only clear text if it is the same as the vehicle's current mileage
                          final current = _selectedVehicle?.mileage ?? '';
                          if (_mileageController.text == current) {
                            _mileageController.clear();
                          }
                        },
                      ),

                      const SizedBox(height: 16),

                      /// AMOUNT
                      TextFormField(
                        controller: _amountController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Amount (RM)',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => _autoCalculatePricePerLiter(),
                      ),
                      const SizedBox(height: 16),

                      /// VOLUME + PRICE
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _volumeController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Volume (L)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => _autoCalculatePricePerLiter(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _priceController,
                              readOnly: true,
                              decoration: const InputDecoration(
                                labelText: 'Price per Liter (RM)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      /// FUEL TYPE
                      DropdownButtonFormField<String>(
                        value: _selectedFuelType,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Type',
                          border: OutlineInputBorder(),
                        ),
                        items: _fuelTypes
                            .map(
                              (t) => DropdownMenuItem(value: t, child: Text(t)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setState(() => _selectedFuelType = v!),
                      ),
                      const SizedBox(height: 16),

                      /// FULL TANK
                      Row(
                        children: [
                          Checkbox(
                            value: _isFullTank,
                            onChanged: (v) =>
                                setState(() => _isFullTank = v ?? false),
                          ),
                          const Text("Full Tank"),
                        ],
                      ),
                      const SizedBox(height: 16),

                      /// STATION
                      TextFormField(
                        controller: _stationController,
                        decoration: const InputDecoration(
                          labelText: 'Fuel Station (Optional)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// DATE
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

                      /// ADD PHOTO
                      OutlinedButton.icon(
                        onPressed: _pickOrCaptureImage,
                        icon: const Icon(Icons.camera_alt),
                        label: Text(
                          _selectedImageBytes == null
                              ? "Add Photo"
                              : "Change Photo",
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
                                final img = snapshot.data!;
                                return AspectRatio(
                                  aspectRatio: img.width / img.height,
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

              /// SAVE BUTTON
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveRecord,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Done', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_isSaving)
          Container(
            color: Colors.black26,
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }

  /// ------------------------------------------------------------
  /// IMAGE PICKER BOTTOM SHEET
  /// ------------------------------------------------------------
  Future<void> _pickOrCaptureImage() async {
    final picker = ImagePicker();

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
                final img = await picker.pickImage(source: ImageSource.gallery);
                if (img != null) {
                  final bytes = await img.readAsBytes();
                  setState(() => _selectedImageBytes = bytes);
                }
                if (mounted) Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a Photo'),
              onTap: () async {
                final img = await picker.pickImage(source: ImageSource.camera);
                if (img != null) {
                  final bytes = await img.readAsBytes();
                  setState(() => _selectedImageBytes = bytes);
                }
                if (mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }
}
