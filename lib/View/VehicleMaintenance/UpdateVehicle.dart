import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart'; // <--- Import for date formatting
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceController.dart';

import '../../Model/vehicle_maintenance_model.dart';

class UpdateVehiclePage extends StatefulWidget {
  final Vehicle vehicleDetails;

  const UpdateVehiclePage({super.key, required this.vehicleDetails});

  @override
  State<UpdateVehiclePage> createState() => _UpdateVehiclePageState();
}

class _UpdateVehiclePageState extends State<UpdateVehiclePage> {
  final VehicleDataService _vehicleService = VehicleDataService();
  final _formKey = GlobalKey<FormState>();

  late TextEditingController brandController;
  late TextEditingController modelController;
  late TextEditingController plateController;
  late TextEditingController colorController;
  late TextEditingController yearController;
  late TextEditingController mileageController;
  late TextEditingController roadTaxController;

  Uint8List? newImageBytes;
  String? previewUrl;
  String? oldImageUrl;
  bool _isLoading = false;

  // Store the initial mileage to enforce validation
  late int initialMileage;

  @override
  void initState() {
    super.initState();
    final v = widget.vehicleDetails;
    brandController = TextEditingController(text: v.brand);
    modelController = TextEditingController(text: v.model);
    plateController = TextEditingController(text: v.plateNumber);
    colorController = TextEditingController(text: v.color);
    yearController = TextEditingController(text: v.manYear.toString());
    mileageController = TextEditingController(text: v.mileage.toString());
    roadTaxController = TextEditingController(text: v.roadTaxExpired);
    previewUrl = v.imageUrl;
    oldImageUrl = v.imageUrl;

    initialMileage = v.mileage; // Store initial mileage
  }

  @override
  void dispose() {
    brandController.dispose();
    modelController.dispose();
    plateController.dispose();
    colorController.dispose();
    yearController.dispose();
    mileageController.dispose();
    roadTaxController.dispose();
    super.dispose();
  }

  Future<void> _pickNewImage() async {
    // ... (image picking logic remains the same)
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          newImageBytes = bytes;
          oldImageUrl = '';
        });
      }
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
    }
  }

  // New function to handle date selection for Road Tax
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: roadTaxController.text.isNotEmpty
          ? DateFormat('dd/MM/yyyy').parse(roadTaxController.text)
          : DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      roadTaxController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    int safeParseInt(String text) {
      return int.tryParse(text.trim()) ?? 0;
    }

    try {
      final updatedVehicle = Vehicle(
        vehicleId: widget.vehicleDetails.vehicleId,
        // CRUCIAL: Use original data for non-editable fields to ensure consistency
        brand: widget.vehicleDetails.brand,
        model: widget.vehicleDetails.model,
        plateNumber: widget.vehicleDetails.plateNumber,
        manYear: widget.vehicleDetails.manYear,
        uid: widget.vehicleDetails.uid,

        // Editable fields use controller text
        color: colorController.text.trim().toUpperCase(),
        roadTaxExpired: roadTaxController.text.trim(),
        mileage: safeParseInt(mileageController.text),
        imageUrl: oldImageUrl ?? '',
      );

      // ✅ Update vehicle and get new URL if image changed
      final newUrl = await _vehicleService.updateVehicle(
        updatedVehicle,
        newImageBytes: newImageBytes,
      );

      // ✅ Refresh local state immediately
      if (mounted) {
        setState(() {
          if (newUrl != null) {
            previewUrl = newUrl;
            oldImageUrl = newUrl;
            newImageBytes = null;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Vehicle updated successfully')),
        );

        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error updating vehicle: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ Failed to update: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Update Vehicle',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
        children: [
          // --- Image ---
          Center(
            child: GestureDetector(
              onTap: _pickNewImage,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _buildImagePreview(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),

          // --- Form ---
          Form(
            key: _formKey,
            child: _buildInputContainer([
              Row(
                children: [
                  Expanded(
                    child: _buildUppercaseField(
                      controller: brandController,
                      hintText: 'Brand',
                      label: 'Brand', // Added Label
                      readOnly: true, // Restricted Field
                      validator: (v) => v!.isEmpty ? 'Brand required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildUppercaseField(
                      controller: modelController,
                      hintText: 'Model',
                      label: 'Model', // Added Label
                      readOnly: true, // Restricted Field
                      validator: (v) => v!.isEmpty ? 'Model required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildUppercaseField(
                controller: plateController,
                hintText: 'Vehicle Plate Number',
                label: 'Vehicle Plate Number', // Added Label
                readOnly: true, // Restricted Field
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Plate required';
                  if (!RegExp(
                    r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9]+$',
                  ).hasMatch(v)) {
                    return 'Must contain letters and numbers';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _buildUppercaseField(
                controller: colorController,
                hintText: 'Color',
                label: 'Color', // Added Label
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Color required';
                  if (!RegExp(r'^[A-Za-z]+$').hasMatch(v)) {
                    return 'Only alphabets allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _buildNumericField(
                controller: yearController,
                hintText: 'Manufacture Year',
                label: 'Manufacture Year', // Added Label
                readOnly: true, // Restricted Field
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Year required';
                  final y = int.tryParse(v);
                  if (y == null || y < 1900 || y > DateTime.now().year + 1) {
                    return 'Invalid year';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _buildNumericField(
                controller: mileageController,
                hintText: 'Mileage',
                label: 'Current Mileage (KM)', // Added Label
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Mileage required';
                  final newMileage = int.tryParse(v);
                  // 🔑 Validation for mileage lower than current
                  if (newMileage != null && newMileage < initialMileage) {
                    return 'Mileage cannot be less than $initialMileage';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: roadTaxController,
                hintText: 'DD/MM/YYYY',
                label: 'Road Tax Expired Date', // Added Label
                readOnly: true, // Make read-only for date picker
                onTap: () => _selectDate(context), // Use date picker
                validator: (v) => v!.isEmpty ? 'Road tax date required' : null,
              ),
              const SizedBox(height: 30),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SizedBox(
                      width: double.infinity, // ✅ Make button take full width
                      child: ElevatedButton(
                        onPressed: _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                            vertical: 14.0,
                          ), // slightly taller
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.0),
                          ),
                        ),
                        child: const Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
            ]),
          ),
        ],
      ),
    );
  }

  // ---------------- Helper Widgets ----------------

  Widget _buildImagePreview() {
    // ... (image preview logic remains the same)
    if (newImageBytes != null) {
      return Image.memory(
        newImageBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
      );
    } else if (previewUrl != null && previewUrl!.isNotEmpty) {
      return Image.network(
        previewUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, error, stack) => _placeholderImage(),
      );
    } else {
      return _placeholderImage();
    }
  }

  Widget _placeholderImage() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Icon(Icons.directions_car, color: Colors.grey, size: 60),
      ),
    );
  }

  Widget _buildInputContainer(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10.0),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 2,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isReadOnly) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: isReadOnly
          ? Colors.grey[100]
          : Colors.white, // Visual cue for read-only
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(
          color: isReadOnly ? Colors.grey.shade300! : Colors.blue,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  // ---------------- MODIFIED HELPER WIDGETS ----------------

  Widget _buildLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0, top: 4.0),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.grey[700],
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    required String label, // New required parameter
    String? Function(String?)? validator,
    bool readOnly = false, // New parameter for restriction
    VoidCallback? onTap, // New parameter for date picker
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label), // Display the label
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          decoration: _inputDecoration(hintText, readOnly),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildUppercaseField({
    required TextEditingController controller,
    required String hintText,
    required String label, // New required parameter
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    bool readOnly = false, // New parameter for restriction
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label), // Display the label
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: inputFormatters,
          validator: validator,
          onChanged: readOnly
              ? null
              : (val) {
                  // Disable onChanged for readOnly
                  controller.value = controller.value.copyWith(
                    text: val.toUpperCase(),
                    selection: TextSelection.collapsed(offset: val.length),
                  );
                },
          decoration: _inputDecoration(hintText, readOnly),
        ),
      ],
    );
  }

  Widget _buildNumericField({
    required TextEditingController controller,
    required String hintText,
    required String label, // New required parameter
    String? Function(String?)? validator,
    bool readOnly = false, // New parameter for restriction
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label), // Display the label
        TextFormField(
          controller: controller,
          readOnly: readOnly,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: validator,
          decoration: _inputDecoration(hintText, readOnly),
        ),
      ],
    );
  }
}
