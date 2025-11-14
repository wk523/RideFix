import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';

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

  @override
  void initState() {
    super.initState();
    final v = widget.vehicleDetails;
    brandController = TextEditingController(text: v.brand);
    modelController = TextEditingController(text: v.model);
    plateController = TextEditingController(text: v.plateNumber);
    colorController = TextEditingController(text: v.color);
    yearController = TextEditingController(text: v.manYear);
    mileageController = TextEditingController(text: v.mileage);
    roadTaxController = TextEditingController(text: v.roadTaxExpired);
    previewUrl = v.imageUrl;
    oldImageUrl = v.imageUrl;
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

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final updatedVehicle = Vehicle(
        vehicleId: widget.vehicleDetails.vehicleId,
        brand: brandController.text.trim().toUpperCase(),
        color: colorController.text.trim().toUpperCase(),
        model: modelController.text.trim().toUpperCase(),
        plateNumber: plateController.text.trim().toUpperCase(),
        manYear: yearController.text.trim(),
        uid: widget.vehicleDetails.uid,
        roadTaxExpired: roadTaxController.text.trim(),
        mileage: mileageController.text.trim(),
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
                      validator: (v) => v!.isEmpty ? 'Brand required' : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildUppercaseField(
                      controller: modelController,
                      hintText: 'Model',
                      validator: (v) => v!.isEmpty ? 'Model required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildUppercaseField(
                controller: plateController,
                hintText: 'Vehicle Plate Number',
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
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                ],
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
                validator: (v) => v!.isEmpty ? 'Mileage required' : null,
              ),
              const SizedBox(height: 10),
              _buildInputField(
                controller: roadTaxController,
                hintText: 'Road Tax Expired Date',
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      decoration: _inputDecoration(hintText),
      validator: validator,
    );
  }

  Widget _buildUppercaseField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      textCapitalization: TextCapitalization.characters,
      inputFormatters: inputFormatters,
      validator: validator,
      onChanged: (val) {
        controller.value = controller.value.copyWith(
          text: val.toUpperCase(),
          selection: TextSelection.collapsed(offset: val.length),
        );
      },
      decoration: _inputDecoration(hintText),
    );
  }

  Widget _buildNumericField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: validator,
      decoration: _inputDecoration(hintText),
    );
  }
}
