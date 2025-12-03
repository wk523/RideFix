import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:ridefix/Controller/EmergencyService/EmergencyServiceController.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceController.dart';
import 'package:ridefix/Model/emergency_service_model.dart';

import '../../Model/vehicle_maintenance_model.dart';

// --- Data Model for the Checklist (Local to this file) ---
class ChecklistItem {
  final DocumentSnapshot userDoc;
  final String title;
  bool isSelected;

  ChecklistItem(this.userDoc, this.title, {this.isSelected = false});
}

class SosConfirmationPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const SosConfirmationPage({super.key, required this.userDoc});

  @override
  State<SosConfirmationPage> createState() => _SosConfirmationPageState();
}

class _SosConfirmationPageState extends State<SosConfirmationPage> {
  // --- State Variables ---
  String _currentAddress = "Fetching location...";
  bool _isSending = false;
  final TextEditingController _plateController = TextEditingController();

  final VehicleDataService _vehicleService = vehicleDataService;
  String? _selectedVehicleId;
  bool _isManualInput = false;

  Vehicle? _selectedVehicle;

  // --- NEW EMERGENCY CONTACT STATE ---
  // Note: EmergencyContact class must be available/imported.
  String? _selectedEmergencyContactId;
  EmergencyContact? _selectedEmergencyContact;
  bool _isManualContactInput = false;
  final TextEditingController _manualNameController = TextEditingController();
  final TextEditingController _manualNumberController = TextEditingController();

  late final List<ChecklistItem> _checklistItems = [
    ChecklistItem(widget.userDoc, 'Flat Tire / Puncture'),
    ChecklistItem(widget.userDoc, 'Engine Overheating / Breakdown'),
    ChecklistItem(widget.userDoc, 'Accident / Collision'),
    ChecklistItem(widget.userDoc, 'Out of Fuel / Battery Dead'),
    ChecklistItem(widget.userDoc, 'Need Towing Service'),
    ChecklistItem(widget.userDoc, 'Other Mechanical Failure'),
  ];

  @override
  void initState() {
    super.initState();
    _fetchAddressOnLoad();
  }

  @override
  void dispose() {
    _plateController.dispose();
    _manualNameController.dispose();
    _manualNumberController.dispose();
    super.dispose();
  }

  Future<void> _fetchAddressOnLoad() async {
    final controller = Provider.of<EmergencyServiceController>(
      context,
      listen: false,
    );

    final address = await controller.fetchAddressFromControllerLocation();

    if (mounted) {
      setState(() {
        _currentAddress = address;
      });
    }
  }

  // --- NEW Save Contact Function ---
  Future<void> _saveManualContact(BuildContext context) async {
    final name = _manualNameController.text.trim();
    final number = _manualNumberController.text.trim();

    if (name.isEmpty || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Name and number cannot be empty to save.'),
        ),
      );
      return;
    }

    final controller = Provider.of<EmergencyServiceController>(
      context,
      listen: false,
    );

    try {
      await controller.saveEmergencyContact(
        uid: widget.userDoc.id,
        name: name,
        number: number,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Contact saved successfully: $name')),
        );
        // Reset selection state to force stream rebuild and prompt user to select the new contact
        setState(() {
          _isManualContactInput = false;
          _selectedEmergencyContact = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save contact: ${e.toString()}')),
        );
      }
    }
  }

  // --- Final SOS Submission Logic ---
  void _sendSos() async {
    if (_isSending) return;

    final controller = Provider.of<EmergencyServiceController>(
      context,
      listen: false,
    );
    final selectedIssues = _checklistItems
        .where((item) => item.isSelected)
        .map((item) => item.title)
        .toList();
    final plateNumber = _plateController.text.trim();

    // ✅ NEW: Determine vehicle brand and model
    final String vehicleBrand = _isManualInput
        ? 'N/A'
        : _selectedVehicle?.brand ?? 'N/A';
    final String vehicleModel = _isManualInput
        ? 'N/A'
        : _selectedVehicle?.model ?? 'N/A';

    // Determine the final emergency contact details
    final String contactNumber =
        _selectedEmergencyContact?.number ??
        (_isManualContactInput ? _manualNumberController.text.trim() : 'N/A');
    final String contactName =
        _selectedEmergencyContact?.name ??
        (_isManualContactInput ? _manualNameController.text.trim() : 'N/A');

    // 1. Simple Validation
    // ... (existing validation) ...
    if (_currentAddress.startsWith('GPS location unavailable')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot send SOS: Current location is unknown.'),
        ),
      );
      return;
    }
    if (selectedIssues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one issue.')),
      );
      return;
    }
    // New contact validation
    if (contactNumber.isEmpty || contactNumber == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select or enter an Emergency Contact Number.'),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      // CALL: Submit the request using the controller function
      await controller.sendSosRequest(
        address: _currentAddress,
        selectedIssues: selectedIssues,
        plateNumber: plateNumber,
        vehicleBrand: vehicleBrand, // ✅ Pass new parameter
        vehicleModel: vehicleModel, // ✅ Pass new parameter
        userDoc: widget.userDoc,
        emergencyContactNumber: contactNumber,
        emergencyContactName: contactName,
      );

      // 4. Confirmation and Navigation (remains in the UI layer)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'SOS Request Sent! Messaging $contactName now via WhatsApp.',
            ),
            duration: const Duration(seconds: 5),
          ),
        );

        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint("SOS Submission Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending request. ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // --- UI Builder ---
  @override
  Widget build(BuildContext context) {
    // Need a non-listening controller instance for the contact stream
    final controller = Provider.of<EmergencyServiceController>(
      context,
      listen: false,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Roadside SOS Checklist'),
        backgroundColor: Colors.red.shade700,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Current Location Display ---
            _buildLocationCard(),
            const SizedBox(height: 20),

            // --- Vehicle Plate Input Header ---
            const Text(
              'Vehicle Plate Number:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // --- Dropdown/StreamBuilder for User's Vehicles (EXISTING) ---
            StreamBuilder<List<Vehicle>>(
              stream: _vehicleService.vehiclesStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LinearProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Text('Error loading vehicles: ${snapshot.error}');
                }

                final List<Vehicle> vehicles = snapshot.data ?? [];

                // Create the Dropdown items
                List<DropdownMenuItem<String>> dropdownItems = [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("Select Registered Vehicle"),
                  ),
                  const DropdownMenuItem(
                    value: "MANUAL_INPUT",
                    child: Text("Enter Plate Number Manually"),
                  ),
                  ...vehicles.map(
                    (v) => DropdownMenuItem(
                      value: v.vehicleId,
                      child: Text("${v.brand} ${v.model} (${v.plateNumber})"),
                    ),
                  ),
                ];

                return DropdownButtonFormField<String?>(
                  isExpanded: true,
                  value: _selectedVehicleId,
                  decoration: const InputDecoration(
                    hintText: 'Select your vehicle or enter manually',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                  items: dropdownItems,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedVehicleId = newValue;

                      if (newValue == "MANUAL_INPUT") {
                        _isManualInput = true;
                        _selectedVehicle = null; // ✅ Reset selected vehicle
                        _plateController.clear();
                      } else {
                        _isManualInput = false;

                        if (newValue != null) {
                          // Find the selected vehicle to get its plate number
                          final selectedVehicle = vehicles.firstWhere(
                            (v) => v.vehicleId == newValue,
                            orElse: () => Vehicle(
                              vehicleId: '',
                              brand: '',
                              color: '',
                              model: '',
                              plateNumber: '',
                              manYear: 0,
                              uid: '',
                              roadTaxExpired: '',
                              mileage: 0,
                              imageUrl: '',
                            ),
                          );

                          _selectedVehicle =
                              selectedVehicle; // ✅ Save the selected vehicle
                          _plateController.text = selectedVehicle.plateNumber;
                        } else {
                          _selectedVehicle = null; // ✅ Reset selected vehicle
                          _plateController.clear();
                        }
                      }
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 10),

            // --- Conditional Manual Plate Input Field (EXISTING) ---
            if (_isManualInput)
              TextField(
                controller: _plateController,
                decoration: const InputDecoration(
                  hintText: 'Enter Plate Number (e.g., ABC 1234)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                textCapitalization: TextCapitalization.characters,
              ),

            // --- Emergency Contact Block (NEW) ---
            const SizedBox(height: 20),
            const Text(
              'Emergency Contact (for WhatsApp SOS)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 1.5),

            // --- Contact Dropdown/StreamBuilder (NEW) ---
            StreamBuilder<List<EmergencyContact>>(
              stream: controller.emergencyContactsStream(widget.userDoc.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LinearProgressIndicator());
                }

                final List<EmergencyContact> contacts = snapshot.data ?? [];

                // --- 1. Compile ALL possible values into a map for easy lookup ---
                Map<String, EmergencyContact> contactMap = {
                  for (var c in contacts) c.id: c,
                };

                // --- 2. Create Dropdown Items, using String for value ---
                List<DropdownMenuItem<String>> dropdownItems = [
                  const DropdownMenuItem(
                    value: null,
                    child: Text("Select Emergency Contact"),
                  ),
                  const DropdownMenuItem(
                    value: "MANUAL_INPUT", // Use String ID
                    child: Text("Enter Contact Manually"),
                  ),
                  ...contacts.map(
                    (c) => DropdownMenuItem(
                      value: c.id, // Use String ID
                      child: Text("${c.name} (${c.number})"),
                    ),
                  ),
                ];

                return DropdownButtonFormField<String?>(
                  // VALUE: Use the new String ID state variable
                  isExpanded: true,
                  value: _selectedEmergencyContactId,
                  decoration: const InputDecoration(
                    // ... (existing decoration) ...
                  ),
                  // ITEMS: Use String
                  items: dropdownItems,
                  selectedItemBuilder: (BuildContext context) {
                    final List<EmergencyContact> contacts = snapshot.data ?? [];
                    final allItems = [
                      null, // for the initial placeholder
                      "MANUAL_INPUT", // for the manual input option
                      ...contacts.map((c) => c.id),
                    ];

                    return allItems.map((id) {
                      String displayText = '';
                      if (id == null) {
                        displayText = "Select Emergency Contact";
                      } else if (id == "MANUAL_INPUT") {
                        displayText = "Enter Contact Manually";
                      } else {
                        final contact = contacts.firstWhere(
                          (c) => c.id == id,
                          orElse: () => EmergencyContact(
                            id: '',
                            name: 'Error',
                            number: '',
                          ),
                        );
                        displayText = "${contact.name} (${contact.number})";
                      }

                      return Text(
                        displayText,
                        // Ensure the text color is dark and visible against the white background
                        style: TextStyle(
                          color:
                              Theme.of(context).textTheme.bodyLarge?.color ??
                              Colors.black,
                        ),
                      );
                    }).toList();
                  },
                  onChanged: (String? newId) {
                    // onChanged takes the String ID
                    setState(() {
                      _selectedEmergencyContactId = newId;

                      _selectedEmergencyContact = contactMap[newId];

                      _isManualContactInput = (newId == "MANUAL_INPUT");

                      if (newId != "MANUAL_INPUT") {
                        _manualNameController.clear();
                        _manualNumberController.clear();
                      }
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 10),

            // --- Conditional Manual Contact Input Field (NEW) ---
            if (_isManualContactInput) ...[
              TextField(
                controller: _manualNameController,
                decoration: const InputDecoration(
                  hintText: 'Contact Name',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _manualNumberController,
                decoration: const InputDecoration(
                  hintText: 'Contact Number (e.g., +60123456789)',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 10),
              // Button to save the manually entered contact
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  onPressed: () => _saveManualContact(context),
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save Contact'),
                ),
              ),
            ],
            const SizedBox(height: 20),
            // --- End of Emergency Contact Block ---

            // --- Checklist Header (EXISTING) ---
            const Text(
              'What seems to be the issue? (Select all that apply)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(thickness: 1.5),

            // --- Checklist Items (EXISTING) ---
            ..._checklistItems
                .map((item) => _buildChecklistTile(item))
                .toList(),

            const SizedBox(height: 30),
          ],
        ),
      ),
      // --- Final SOS Button (EXISTING) ---
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _isSending ? null : _sendSos,
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.call, size: 24),
            label: Text(
              _isSending ? 'Sending Request...' : 'SEND SOS',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade800,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- Helper Widgets (EXISTING) ---

  Widget _buildLocationCard() {
    // Note: This needs a listening Provider call to update location if the controller updates it
    final controller = Provider.of<EmergencyServiceController>(context);
    final LatLng? location = controller.currentPosition;

    return Card(
      elevation: 4,
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Current Location (Crucial)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const Divider(),
            if (location != null)
              Text(
                'Coordinates: ${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}',
                style: const TextStyle(fontSize: 14),
              ),
            const SizedBox(height: 4),
            Text(
              'Address: $_currentAddress',
              style: const TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
            ),
            if (_currentAddress == "Fetching location...")
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistTile(ChecklistItem item) {
    return CheckboxListTile(
      title: Text(item.title),
      value: item.isSelected,
      onChanged: (bool? newValue) {
        setState(() {
          item.isSelected = newValue ?? false;
        });
      },
      activeColor: Colors.red,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
