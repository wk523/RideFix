import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/ServiceRecord/ServiceRecordDatabase.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';

enum ServiceCategory {
  none,
  maintenance,
  toll,
  parking,
  carWash,
  insurance,
  roadTax,
  installment,
  makeup,
}

extension ServiceCategoryExtension on ServiceCategory {
  String get displayName {
    switch (this) {
      case ServiceCategory.maintenance:
        return 'Maintenance';
      case ServiceCategory.toll:
        return 'Toll';
      case ServiceCategory.parking:
        return 'Parking';
      case ServiceCategory.carWash:
        return 'Car Wash';
      case ServiceCategory.insurance:
        return 'Insurance';
      case ServiceCategory.roadTax:
        return 'Road Tax';
      case ServiceCategory.installment:
        return 'Installment';
      case ServiceCategory.makeup:
        return 'Makeup';
      case ServiceCategory.none:
      default:
        return 'Select Category';
    }
  }

  IconData get icon {
    switch (this) {
      case ServiceCategory.maintenance:
        return Icons.settings;
      case ServiceCategory.toll:
        return Icons.traffic;
      case ServiceCategory.parking:
        return Icons.local_parking;
      case ServiceCategory.carWash:
        return Icons.local_car_wash;
      case ServiceCategory.insurance:
        return Icons.security;
      case ServiceCategory.roadTax:
        return Icons.attach_money;
      case ServiceCategory.installment:
        return Icons.credit_card;
      case ServiceCategory.makeup:
        return Icons.brush;
      case ServiceCategory.none:
      default:
        return Icons.category;
    }
  }
}

class AddServiceRecordPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const AddServiceRecordPage({super.key, required this.userDoc});

  @override
  State<AddServiceRecordPage> createState() => _AddServiceRecordPageState();
}

class _AddServiceRecordPageState extends State<AddServiceRecordPage> {
  ServiceCategory _selectedCategory = ServiceCategory.none;
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();

  final VehicleDataService _vehicleService = VehicleDataService();
  List<Vehicle> _vehicleList = [];
  Vehicle? _selectedVehicle;

  final ServiceRecordDatabase _serviceDb = ServiceRecordDatabase();

  Uint8List? _selectedImageBytes;
  String? _uploadedImageUrl;
  Map<String, dynamic> _extraFormData = {};

  DateTime? _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
    _selectedDate = DateTime.now();
    _dateController.text = DateFormat('dd/MM/yyyy').format(_selectedDate!);
  }

  Future<void> _loadVehicles() async {
    final list = await _vehicleService.readVehicleData();
    setState(() => _vehicleList = list);
  }

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

  /// ✅ Image picker modal
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

  Future<void> _saveRecord() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a vehicle')));
      return;
    }

    final category = _selectedCategory.displayName;
    final amount = double.tryParse(_amountController.text) ?? 0;
    final date = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : '';

    if (category == 'Select Category' || amount <= 0 || date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Please complete all required fields.'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // ✅ 1. Handle image upload (optional)
      String? imgURL;
      if (_selectedImageBytes != null) {
        imgURL = await _serviceDb.uploadServiceImage(_selectedImageBytes!);
      }

      // ✅ 2. Handle mileage validation + update (only for maintenance)
      if (_extraFormData.containsKey('mileage')) {
        final enteredMileageText = _extraFormData['mileage']?.toString().trim();

        // 1. Get current mileage as an int (it's now an int in the Vehicle model)
        // Use ?? 0 for safety, as '0' is not needed after the type change.
        final currentMileage = _selectedVehicle?.mileage ?? 0;

        if (enteredMileageText != null && enteredMileageText.isNotEmpty) {
          // 2. Parse the entered text directly to an int
          final enteredMileage = int.tryParse(enteredMileageText);

          // 3. Compare the integer values
          if (enteredMileage != null) {
            if (enteredMileage < currentMileage) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    '⚠️ Mileage cannot be lower than current vehicle mileage.',
                  ),
                ),
              );
              setState(() => _isSaving = false);
              return;
            } else if (enteredMileage > currentMileage) {
              // 4. Update the service function call
              // The updateVehicleMileage function now expects an int.
              await VehicleDataService().updateVehicleMileage(
                _selectedVehicle!.vehicleId,
                enteredMileage, // Passed as int
              );
            }
          }
          // Note: If enteredMileage is null (invalid format), it skips the logic,
          // assuming validation handles the initial input formatting error elsewhere.
        }
      }

      // ✅ 3. Save service record
      await _serviceDb.addServiceRecord(
        uid: uid,
        vehicleId: _selectedVehicle!.vehicleId,
        category: category,
        amount: amount,
        date: date,
        note: _noteController.text.trim(),
        imgURL: imgURL,
        extraData: _extraFormData.isEmpty ? null : _extraFormData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Service record saved successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Widget _buildCategoryForm() {
    switch (_selectedCategory) {
      case ServiceCategory.maintenance:
        return MaintenanceForm(
          onChanged: (data) => _extraFormData = data,
          initialMileage: _selectedVehicle?.mileage?.toString(),
        );

      case ServiceCategory.roadTax:
        return RoadTaxForm(onChanged: (data) => _extraFormData = data);
      case ServiceCategory.insurance:
        return InsuranceForm(onChanged: (data) => _extraFormData = data);
      case ServiceCategory.carWash:
        return CarWashForm(onChanged: (data) => _extraFormData = data);
      default:
        return SimpleExpenseForm(controller: _noteController);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text(
              'Add Service Record',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
            backgroundColor: Colors.blue,
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
                      /// Vehicle dropdown
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
                        onChanged: (value) =>
                            setState(() => _selectedVehicle = value),
                      ),
                      const SizedBox(height: 20),

                      /// Category
                      GestureDetector(
                        onTap: _showCategorySelectionModal,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.arrow_drop_down),
                          ),
                          child: Text(_selectedCategory.displayName),
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// Dynamic form
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: _buildCategoryForm(),
                      ),
                      const SizedBox(height: 16),

                      /// Amount
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

                      /// Date
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

              // Fixed Save button
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
                      'Save Record',
                      style: TextStyle(fontSize: 18),
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

  void _showCategorySelectionModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        height: 230, // <-- limit modal height
        child: GridView.count(
          padding: const EdgeInsets.all(16),
          crossAxisCount: 4,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          children: ServiceCategory.values
              .where((c) => c != ServiceCategory.none)
              .map(
                (category) => InkWell(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                      _extraFormData = {};
                    });
                    Navigator.pop(context);
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(category.icon, color: Colors.blue),
                      ),
                      const SizedBox(height: 4),
                      Text(category.displayName, textAlign: TextAlign.center),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// --- Specific Form Components ---

class SimpleExpenseForm extends StatelessWidget {
  final TextEditingController controller;
  const SimpleExpenseForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('simple_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description (Optional)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'e.g., Highway toll from KL to Penang',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 2,
        ),
      ],
    );
  }
}

class MaintenanceForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onChanged;
  final String? initialMileage;
  const MaintenanceForm({
    super.key,
    required this.onChanged,
    this.initialMileage,
  });

  @override
  State<MaintenanceForm> createState() => _MaintenanceFormState();
}

class _MaintenanceFormState extends State<MaintenanceForm> {
  final TextEditingController _serviceProviderController =
      TextEditingController();
  final TextEditingController _mileageController = TextEditingController();
  final TextEditingController _performedServiceController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _mileageController.text = widget.initialMileage ?? ''; // 👈 preload mileage
    _serviceProviderController.addListener(_notifyParent);
    _mileageController.addListener(_notifyParent);
    _performedServiceController.addListener(_notifyParent);
  }

  void _notifyParent() {
    widget.onChanged({
      'serviceProvider': _serviceProviderController.text,
      'mileage': _mileageController.text,
      'performedService': _performedServiceController.text,
    });
  }

  @override
  void dispose() {
    _serviceProviderController.dispose();
    _mileageController.dispose();
    _performedServiceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('maintenance_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'MAINTENANCE DETAILS',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _serviceProviderController,
          decoration: InputDecoration(
            labelText: 'Service Provider Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _mileageController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],

          decoration: InputDecoration(
            labelText: 'Current Mileage',
            hintText: widget.initialMileage != null
                ? 'Current: ${widget.initialMileage} km'
                : 'Enter mileage',
            suffixText: 'km',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onTap: () {
            // Optionally clear only when tapped (if you had a default value before)
            if (_mileageController.text == widget.initialMileage) {
              _mileageController.clear();
            }
          },
        ),

        const SizedBox(height: 16),
        TextFormField(
          controller: _performedServiceController,
          decoration: InputDecoration(
            labelText: 'Service Performed',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          maxLines: 3,
        ),
      ],
    );
  }
}

class InsuranceForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onChanged;
  const InsuranceForm({super.key, required this.onChanged});

  @override
  State<InsuranceForm> createState() => _InsuranceFormState();
}

class _InsuranceFormState extends State<InsuranceForm> {
  final _insuranceCompanyController = TextEditingController();
  final _policyNumberController = TextEditingController();
  final _insuranceExpiryController = TextEditingController();

  Future<void> _pickExpiryDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _insuranceExpiryController.text = DateFormat(
          'dd/MM/yyyy',
        ).format(picked);
        widget.onChanged({
          'insuranceCompany': _insuranceCompanyController.text,
          'policyNumber': _policyNumberController.text,
          'expiryDate': _insuranceExpiryController.text,
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _insuranceCompanyController.addListener(_update);
    _policyNumberController.addListener(_update);
  }

  void _update() {
    widget.onChanged({
      'insuranceCompany': _insuranceCompanyController.text,
      'policyNumber': _policyNumberController.text,
      'expiryDate': _insuranceExpiryController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('insurance_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'INSURANCE DETAILS',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _insuranceCompanyController,
          decoration: const InputDecoration(
            labelText: 'Insurance Company',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _policyNumberController,
          decoration: const InputDecoration(
            labelText: 'Policy Number',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _insuranceExpiryController,
          readOnly: true,
          onTap: _pickExpiryDate,
          decoration: const InputDecoration(
            labelText: 'Expiry Date',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.calendar_today),
          ),
        ),
      ],
    );
  }
}

class CarWashForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onChanged;
  const CarWashForm({super.key, required this.onChanged});

  @override
  State<CarWashForm> createState() => _CarWashFormState();
}

class _CarWashFormState extends State<CarWashForm> {
  final _washTypeController = TextEditingController();
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _washTypeController.addListener(_update);
    _locationController.addListener(_update);
  }

  void _update() {
    widget.onChanged({
      'washType': _washTypeController.text,
      'location': _locationController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('carwash_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CAR WASH DETAILS',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _washTypeController,
          decoration: const InputDecoration(
            labelText: 'Wash Type (e.g., Interior, Exterior, Full)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Location',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}

class RoadTaxForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onChanged;
  const RoadTaxForm({super.key, required this.onChanged});

  @override
  State<RoadTaxForm> createState() => _RoadTaxFormState();
}

class _RoadTaxFormState extends State<RoadTaxForm> {
  final TextEditingController _periodController = TextEditingController();
  final TextEditingController _expirationController = TextEditingController();

  Future<void> _pickExpirationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Colors.blue,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _expirationController.text = DateFormat('dd/MM/yyyy').format(picked);
        widget.onChanged({
          'periodMonths': _periodController.text,
          'expirationDate': _expirationController.text,
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _periodController.addListener(() {
      widget.onChanged({
        'periodMonths': _periodController.text,
        'expirationDate': _expirationController.text,
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('roadtax_form'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ROAD TAX DETAILS',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _periodController,
          decoration: InputDecoration(
            labelText: 'Period (Months)',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _expirationController,
          readOnly: true,
          onTap: _pickExpirationDate,
          decoration: InputDecoration(
            labelText: 'Expiration Date',
            hintText: 'Select Date',
            prefixIcon: const Icon(Icons.calendar_today),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
