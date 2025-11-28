// AddFuelEntryPage.dart (Complete corrected file)

// import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/Fuel&MileageAnalytics/FuelAnalyticsController.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceController.dart';

import '../../Model/vehicle_maintenance_model.dart';

class AddFuelEntryPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const AddFuelEntryPage({super.key, required this.userDoc});

  @override
  State<AddFuelEntryPage> createState() => _AddFuelEntryPageState();
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

  // VehicleDataService instance is used for vehicle list and now for mileage update
  final VehicleDataService _vehicleService = VehicleDataService();
  final FuelEntryDatabase _fuelService = FuelEntryDatabase();

  String _selectedFuelType = "RON95";
  bool _isFullTank = false;
  Uint8List? _selectedImageBytes;

  DateTime? _selectedDate = DateTime.now();
  bool _isSaving = false;

  final _fuelTypes = ["RON95", "RON97", "DIESEL", "EV CHARGE", "OTHER"];

  // DEFINE THRESHOLD: 15% drop from average efficiency
  static const double _FE_DROP_THRESHOLD = 0.15;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _dateController.text = DateFormat("yyyy-MM-dd").format(DateTime.now());
  }

  /// ❌ ERROR FIX: dispose MUST NOT be nested inside initState.
  @override
  void dispose() {
    _mileageController.dispose();
    _amountController.dispose();
    _volumeController.dispose();
    _priceController.dispose();
    _stationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  /// ------------------------------------------------------------
  /// READ VEHICLE LIST (Fixed: Explicitly type 'list')
  /// ------------------------------------------------------------
  Future<void> _loadVehicles() async {
    // FIX: Explicitly specify the type to prevent type inference errors
    final List<Vehicle> list = await _vehicleService.readVehicleData();

    // Using a block with setState for multiline operations
    setState(() {
      _vehicleList = list;
    });

    if (_selectedVehicle == null && _vehicleList.isNotEmpty) {
      _selectedVehicle = _vehicleList.first;
      _mileageController.text = _selectedVehicle!.mileage.toString();
    }
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
  /// SAFE MILEAGE PARSER (Returns int)
  /// ------------------------------------------------------------
  int _safeMileageParse(String? value) {
    if (value == null) return 0;
    final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(cleaned) ?? 0;
  }

  /// ------------------------------------------------------------
  /// Success Dialog (Updated with drop check)
  /// ------------------------------------------------------------
  Future<void> _showSuccessDialog(
    double fuelEfficiency,
    bool isSeriousDrop,
  ) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            isSeriousDrop ? "Warning: Maintenance Check" : "Fuel Entry Saved",
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment
                .center, // Ensures content is centered horizontally
            children: [
              // UPDATE ICON AND MESSAGE FOR DROP
              Icon(
                isSeriousDrop
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle,
                size: 50,
                color: isSeriousDrop ? Colors.orange : Colors.green,
              ),
              const SizedBox(height: 12),
              if (isSeriousDrop) ...[
                const Text(
                  "Serious Fuel Efficiency Drop!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Your fuel efficiency dropped by over 15%. This could indicate a maintenance issue. Please check your car.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
              ],
              const Text(
                "Fuel Efficiency:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 12),
              Text(
                fuelEfficiency > 0
                    ? "${fuelEfficiency.toStringAsFixed(2)} km/L"
                    : "N/A (Not a full tank entry or no previous full tank data)",
                style: const TextStyle(fontSize: 20, color: Colors.blue),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
          actionsAlignment: MainAxisAlignment
              .center, // Explicitly centers the actions (the "OK" button)
        );
      },
    );
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
  /// SAVE RECORD (Updated with drop check)
  /// ------------------------------------------------------------
  Future<void> _saveRecord() async {
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please select a vehicle.")));
      return;
    }

    // --- VALIDATION ---
    final inputDate = DateFormat("yyyy-MM-dd").parse(_dateController.text);
    if (inputDate.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("⚠️ Date cannot be in the future.")),
      );
      return;
    }

    final mileageEntered = _safeMileageParse(_mileageController.text);
    final currentMileage = (_selectedVehicle!.mileage);

    if (mileageEntered <= currentMileage) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "⚠️ Mileage cannot be same/lower than current mileage (${currentMileage} km).",
          ),
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

    final pricePerLiter = amount / volume;
    setState(() => _isSaving = true);

    // --- IMAGE UPLOAD ---
    String? imgUrl;
    if (_selectedImageBytes != null) {
      imgUrl = await _fuelService.uploadFuelImage(_selectedImageBytes!);
    }

    // --- FUEL EFFICIENCY CALCULATION (Tank-to-Tank Logic) ---
    double fuelEfficiency = 0;
    int lastFullTankMileage = 0;
    double totalIntermediateVolume = 0;

    if (_isFullTank) {
      final result = await _fuelService.getSummarySinceLastFullTank(
        _selectedVehicle!.vehicleId,
      );

      // Assuming the result structure:
      lastFullTankMileage = result['lastFullTankMileage'] ?? 0;
      totalIntermediateVolume = result['totalVolumeSinceLastFullTank'] ?? 0.0;

      // Total volume for the current cycle (Last Full Tank -> Current Full Tank)
      // is the total intermediate volume PLUS the volume of the CURRENT fill.
      final double totalVolumeUsed = totalIntermediateVolume + volume;

      debugPrint('DEBUG FE: Current Full Tank: $_isFullTank');
      debugPrint('DEBUG FE: Last Full Tank Mileage: $lastFullTankMileage km');
      debugPrint(
        'DEBUG FE: Total Volume Since Last Full Tank: ${totalIntermediateVolume.toStringAsFixed(2)} L',
      );
      debugPrint(
        'DEBUG FE: Current Fill Volume: ${volume.toStringAsFixed(2)} L',
      );
      debugPrint(
        'DEBUG FE: Total Volume Used for Cycle: ${totalVolumeUsed.toStringAsFixed(2)} L',
      );

      if (lastFullTankMileage > 0 &&
          mileageEntered > lastFullTankMileage &&
          totalVolumeUsed > 0) {
        final double distance = (mileageEntered - lastFullTankMileage)
            .toDouble();
        // Formula: Distance / Total Volume (including current fill)
        fuelEfficiency = distance / totalVolumeUsed;
        debugPrint(
          'DEBUG FE: Calculated Efficiency: ${fuelEfficiency.toStringAsFixed(2)} km/L',
        );
      }
    } else {
      // Not a full tank. Efficiency is not calculated (it remains 0)
      debugPrint('DEBUG FE: Not a full tank entry, efficiency skipped.');
    }

    // CHECK FOR SERIOUS DROP
    bool isSeriousDrop = false;
    if (_isFullTank && fuelEfficiency > 0) {
      // The method FuelEntryDatabase.getAverageFuelEfficiency was implemented in the previous step
      final double avgFe = await _fuelService.getAverageFuelEfficiency(
        _selectedVehicle!.vehicleId,
      );

      debugPrint(
        'DEBUG FE: Average Efficiency: ${avgFe.toStringAsFixed(2)} km/L',
      );

      if (avgFe > 0) {
        final double dropPercentage = (avgFe - fuelEfficiency) / avgFe;
        debugPrint(
          'DEBUG FE: Drop Percentage: ${(dropPercentage * 100).toStringAsFixed(2)}%',
        );

        // IMPLEMENT DROP CHECK LOGIC
        if (dropPercentage >= _FE_DROP_THRESHOLD) {
          isSeriousDrop = true;
        }
      }
    }

    // --- SAVE FUEL ENTRY ---
    await _fuelService.addFuelEntry(
      uid: FirebaseAuth.instance.currentUser!.uid,
      vehicleId: _selectedVehicle!.vehicleId,
      amount: amount,
      volumeL: volume,
      pricePerLiter: pricePerLiter,
      fuelType: _selectedFuelType,
      station: _stationController.text,
      mileage: mileageEntered,
      date: _dateController.text,
      isFullTank: _isFullTank,
      imgURL: imgUrl,
      fuelEfficiency: fuelEfficiency, // Store the calculated result (or 0)
    );

    // --- UPDATE VEHICLE MILEAGE (Using existing VehicleDataService) ---
    if (mileageEntered > currentMileage) {
      await _vehicleService.updateVehicleMileage(
        _selectedVehicle!.vehicleId,
        mileageEntered,
      );

      // Update the local vehicle object for immediate UI reflection
      setState(() {
        _selectedVehicle = _selectedVehicle!.copyWith(mileage: mileageEntered);
        final index = _vehicleList.indexWhere(
          (v) => v.vehicleId == _selectedVehicle!.vehicleId,
        );
        if (index != -1) {
          _vehicleList[index] = _selectedVehicle!;
        }
      });
    }

    setState(() => _isSaving = false);

    // --- SHOW POPUP ---
    // Pass the flag to the success dialog
    await _showSuccessDialog(fuelEfficiency, isSeriousDrop);

    if (mounted) Navigator.pop(context, true);
  }

  /// ------------------------------------------------------------
  /// UI
  /// ------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // ... (UI code) ...
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
                        value:
                            _selectedVehicle, // Use value instead of initialValue
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
                          FilteringTextInputFormatter
                              .digitsOnly, // <-- Only digits allowed
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
                          final current =
                              _selectedVehicle?.mileage.toString() ?? '';
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
                          // Allows digits and a single decimal point
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d*'),
                          ),
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
                                // Allows digits and a single decimal point
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d*'),
                                ),
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
                    child: const Text(
                      'Done',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
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
