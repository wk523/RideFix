import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';

class VehicleRegistrationPage extends StatefulWidget {
  const VehicleRegistrationPage({super.key});

  @override
  State<VehicleRegistrationPage> createState() =>
      _VehicleRegistrationPageState();
}

class _VehicleRegistrationPageState extends State<VehicleRegistrationPage> {
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController plateController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController mileageController = TextEditingController();
  final TextEditingController roadTaxController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  Uint8List? _pickedImageBytes;
  String? _pickedImagePreviewPlate;
  DateTime? _selectedRoadTaxDate; // 👈 for date picker

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: const Text(
          'Vehicle Registration',
          style: TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
        children: [
          Center(
            child: GestureDetector(
              onTap: () async {
                final bytes = await vehicleDataService.pickImage();
                if (bytes != null) {
                  setState(() {
                    _pickedImageBytes = bytes;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Image selected')),
                  );
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: _pickedImageBytes != null
                      ? Image.memory(
                          _pickedImageBytes!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: Icon(
                              Icons.camera_alt,
                              color: Colors.grey,
                              size: 50,
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),

          Form(
            key: _formKey,
            child: Column(
              children: [
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
                    if (v == null || v.isEmpty) return 'Plate number required';
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
                _buildInputField(
                  controller: yearController,
                  hintText: 'Manufacture Year',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                _buildInputField(
                  controller: mileageController,
                  hintText: 'Mileage',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v!.isEmpty ? 'Mileage required' : null,
                ),

                const SizedBox(height: 10),

                // 👇 Road Tax Expiry Date Picker
                GestureDetector(
                  onTap: _selectRoadTaxDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      controller: roadTaxController,
                      readOnly: true,
                      decoration: InputDecoration(
                        hintText: 'Road Tax Expired Date',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(5),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Road tax date required' : null,
                    ),
                  ),
                ),

                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _registerVehicle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Register Vehicle',
                            style: TextStyle(color: Colors.white, fontSize: 18),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------- Date Picker --------------------------
  Future<void> _selectRoadTaxDate() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedRoadTaxDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              secondary: Colors.blueAccent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedRoadTaxDate = picked;
        roadTaxController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  // -------------------------- Helper Widgets --------------------------
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: _inputDecoration(hintText),
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

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  // -------------------------- Register Vehicle --------------------------
  Future<void> _registerVehicle() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final vehicleId = DateTime.now().millisecondsSinceEpoch.toString();
    String imageUrl = '';

    try {
      if (_pickedImageBytes != null) {
        final plateForName = plateController.text.trim().isEmpty
            ? 'UNKNOWN'
            : plateController.text.trim().toUpperCase();
        final uploaded = await vehicleDataService.uploadImageFromBytes(
          _pickedImageBytes!,
          plateForName,
        );

        if (uploaded != null) {
          imageUrl = uploaded;
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image upload failed — continuing without image.'),
            ),
          );
        }
      }

      final vehicle = Vehicle(
        vehicleId: vehicleId,
        brand: brandController.text.trim().toUpperCase(),
        color: colorController.text.trim().toUpperCase(),
        model: modelController.text.trim().toUpperCase(),
        plateNumber: plateController.text.trim().toUpperCase(),
        manYear: yearController.text.trim(),
        ownerId: 'user123',
        roadTaxExpired: roadTaxController.text.trim(),
        mileage: mileageController.text.trim(),
        imageUrl: imageUrl,
      );

      await vehicleDataService.registerVehicle(vehicle);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle registered successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
