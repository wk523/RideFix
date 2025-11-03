import 'dart:typed_data';
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
  const AddServiceRecordPage({super.key});

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
  Map<String, dynamic>? _extraFormData;

  @override
  void initState() {
    super.initState();
    _loadVehicles();
  }

  Future<void> _loadVehicles() async {
    final list = await _vehicleService.readVehicleData();
    setState(() {
      _vehicleList = list;
    });
  }

  DateTime? _selectedDate;

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  /// ✅ Pick or take photo
  Future<void> _pickOrCaptureImage() async {
    final ImagePicker picker = ImagePicker();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
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
                    final bytes = await image.readAsBytes();
                    setState(() => _selectedImageBytes = bytes);
                  }
                  Navigator.pop(context);
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
                    final bytes = await photo.readAsBytes();
                    setState(() => _selectedImageBytes = bytes);
                  }
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveRecord() async {
    const userId = 'weikit523';

    if (_selectedVehicle == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a vehicle')));
      return;
    }

    String category = _selectedCategory.displayName;
    switch (category) {
      case 'Car Wash':
        category = 'CarWash';
        break;
      case 'Road Tax':
        category = 'RoadTax';
        break;
      default:
        category = category.replaceAll(' ', '');
        break;
    }

    final amount = double.tryParse(_amountController.text) ?? 0;
    final date = _selectedDate != null
        ? DateFormat('yyyy-MM-dd').format(_selectedDate!)
        : '';

    if (category.isEmpty || amount == 0 || date.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '⚠️ Please enter a valid amount greater than 0 and fill all required fields.',
          ),
        ),
      );
      return;
    }

    String? imgURL;
    if (_selectedImageBytes != null) {
      imgURL = await _serviceDb.uploadServiceImage(_selectedImageBytes!);
    }

    // ✅ Step 1: Prepare extraData based on selected category
    Map<String, dynamic>? extraData;

    try {
      // ✅ Step 2: Pass extraData to your database function
      await _serviceDb.addServiceRecord(
        userId: userId,
        vehicleId: _selectedVehicle!.vehicleId,
        category: category,
        amount: amount,
        date: date,
        note: _noteController.text,
        imgURL: imgURL,
        extraData: _extraFormData, // ✅ this already has your form data
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Service record saved successfully'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Error: $e')));
    }
  }

  /// ✅ Dynamic category form builder
  Widget _buildCategoryForm() {
    switch (_selectedCategory) {
      case ServiceCategory.maintenance:
        return MaintenanceForm(onChanged: (data) => _extraFormData = data);
      case ServiceCategory.roadTax:
        return RoadTaxForm(onChanged: (data) => _extraFormData = data);
      case ServiceCategory.insurance:
        return InsuranceForm(onChanged: (data) => _extraFormData = data);
      case ServiceCategory.carWash:
        return CarWashForm(onChanged: (data) => _extraFormData = data);
      default:
        return const SimpleExpenseForm();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Service Record')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<Vehicle>(
              value: _selectedVehicle,
              decoration: InputDecoration(
                labelText: 'Select Vehicle',
                labelStyle: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.directions_car, color: Colors.grey[600]),
              ),
              items: _vehicleList.map((v) {
                return DropdownMenuItem<Vehicle>(
                  value: v,
                  child: Text('${v.brand} ${v.model} (${v.plateNumber})'),
                );
              }).toList(),
              onChanged: (value) => setState(() => _selectedVehicle = value),
            ),
            const SizedBox(height: 24),

            // ✅ Category
            GestureDetector(
              onTap: () => _showCategorySelectionModal(),
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'CATEGORY',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: Icon(
                    _selectedCategory.icon,
                    color: Colors.grey[600],
                  ),
                  suffixIcon: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
                child: Text(_selectedCategory.displayName),
              ),
            ),
            const SizedBox(height: 24),

            // ✅ Show dynamic form
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCategoryForm(),
            ),
            const SizedBox(height: 24),

            // ✅ Amount
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'AMOUNT',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixText: 'RM ',
                prefixStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'^\d*\.?\d{0,2}'),
                ), // ✅ only numbers + up to 2 decimals
              ],
            ),
            const SizedBox(height: 24),

            // ✅ Date Picker
            TextFormField(
              controller: _dateController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'Date',
                hintText: 'Select Date',
                prefixIcon: const Icon(
                  Icons.calendar_today,
                  color: Colors.blue,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),

            // ✅ Add Photo
            OutlinedButton.icon(
              onPressed: _pickOrCaptureImage,
              icon: const Icon(Icons.camera_alt),
              label: Text(
                _selectedImageBytes == null ? 'Add Photo' : 'Change Photo',
              ),
            ),
            if (_selectedImageBytes != null) ...[
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                    ),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _saveRecord,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Done', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  // --- Category Selection Modal ---
  void _showCategorySelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: GridView.count(
            shrinkWrap: true,
            crossAxisCount: 4,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: ServiceCategory.values
                .where((cat) => cat != ServiceCategory.none)
                .map(
                  (category) => InkWell(
                    onTap: () {
                      setState(() => _selectedCategory = category);
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
                          child: Icon(
                            category.icon,
                            size: 30,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          category.displayName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

/// --- Specific Form Components ---

class SimpleExpenseForm extends StatelessWidget {
  const SimpleExpenseForm({super.key});

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
  const MaintenanceForm({super.key, required this.onChanged});

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
    // Listen to text changes and call the callback
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
          decoration: InputDecoration(
            labelText: 'Current Mileage',
            suffixText: 'km',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
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
