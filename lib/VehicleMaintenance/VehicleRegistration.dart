import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';

class VehicleRegistrationPage extends StatefulWidget {
  const VehicleRegistrationPage({super.key});

  @override
  State<VehicleRegistrationPage> createState() =>
      _VehicleRegistrationPageState();
}

class _VehicleRegistrationPageState extends State<VehicleRegistrationPage> {
  // Controllers
  final TextEditingController brandController = TextEditingController();
  final TextEditingController modelController = TextEditingController();
  final TextEditingController plateController = TextEditingController();
  final TextEditingController colorController = TextEditingController();
  final TextEditingController yearController = TextEditingController();
  final TextEditingController mileageController = TextEditingController();
  final TextEditingController roadTaxController = TextEditingController();

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () =>
              Navigator.pop(context, true), // ✅ return "true" to refresh list
        ),
        title: const Text(
          'Vehicle Registration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 20.0),
        children: [
          // --- Vehicle Image ---
          Center(
            child: GestureDetector(
              onTap: () {
                // TODO: Handle image picking
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.grey.shade600,
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 30),

          // --- Form Fields ---
          Form(
            key: _formKey,
            child: Container(
              padding: const EdgeInsets.all(16.0),
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildUppercaseField(
                          controller: brandController,
                          hintText: 'Brand',
                          validator: (v) =>
                              v!.isEmpty ? 'Brand is required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildUppercaseField(
                          controller: modelController,
                          hintText: 'Model',
                          validator: (v) =>
                              v!.isEmpty ? 'Model is required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Plate Number (Uppercase + Validation)
                  _buildUppercaseField(
                    controller: plateController,
                    hintText: 'Vehicle Plate Number',
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Plate number is required';
                      }
                      final pattern = RegExp(
                        r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9]+$',
                      );
                      if (!pattern.hasMatch(v)) {
                        return 'Must contain both letters and numbers';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Color (Alphabet only)
                  _buildUppercaseField(
                    controller: colorController,
                    hintText: 'Color',
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]')),
                    ],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Color is required';
                      if (!RegExp(r'^[A-Za-z]+$').hasMatch(v)) {
                        return 'Color must only contain alphabets';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Manufacture Year (Numbers only)
                  _buildInputField(
                    controller: yearController,
                    hintText: 'Manufacture Year',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) {
                      if (v == null || v.isEmpty) {
                        return 'Year is required';
                      }
                      final year = int.tryParse(v);
                      if (year == null ||
                          year < 1900 ||
                          year > DateTime.now().year + 1) {
                        return 'Invalid year';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),

                  // Mileage (Numbers only)
                  _buildInputField(
                    controller: mileageController,
                    hintText: 'Mileage',
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (v) => v!.isEmpty ? 'Mileage is required' : null,
                  ),
                  const SizedBox(height: 10),

                  _buildInputField(
                    controller: roadTaxController,
                    hintText: 'Road Tax Expired Date',
                    validator: (v) =>
                        v!.isEmpty ? 'Road tax date is required' : null,
                  ),
                  const SizedBox(height: 30),

                  // Register Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 50.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _registerVehicle,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25.0),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Register',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper: Normal Input Field (no auto-uppercase) ---
  Widget _buildInputField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 12.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  // --- Helper: Auto-uppercase Input Field ---
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
      onChanged: (value) {
        controller.value = controller.value.copyWith(
          text: value.toUpperCase(),
          selection: TextSelection.collapsed(offset: value.length),
        );
      },
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12.0,
          vertical: 12.0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(5.0),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
    );
  }

  // --- Handle Registration ---
  Future<void> _registerVehicle() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final newVehicle = Vehicle(
      vehicleId: DateTime.now().millisecondsSinceEpoch.toString(),
      brand: brandController.text.trim().toUpperCase(),
      color: colorController.text.trim().toUpperCase(),
      model: modelController.text.trim().toUpperCase(),
      plateNumber: plateController.text.trim().toUpperCase(),
      manYear: yearController.text.trim(),
      ownerId: 'user123', // replace with FirebaseAuth user
      roadTaxExpired: roadTaxController.text.trim(),
      mileage: mileageController.text.trim(),
      imageUrl: '', // placeholder
    );

    try {
      await vehicleDataService.registerVehicle(newVehicle);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehicle registered successfully!')),
      );
      Navigator.pop(context, true); // ✅ return to refresh list
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
