// ServiceRecordPage.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/ServiceRecord/ServiceRecordDatabase.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ridefix/View/ServiceRecord/AddServiceRecord.dart';
import 'package:ridefix/View/ServiceRecord/ServiceRecordDetails.dart';

class ServiceRecordPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const ServiceRecordPage({super.key, required this.userDoc});

  @override
  State<ServiceRecordPage> createState() => _ServiceRecordPageState();
}

class _ServiceRecordPageState extends State<ServiceRecordPage> {
  final ServiceRecordDatabase serviceRecordDB = ServiceRecordDatabase();
  final VehicleDataService vehicleService = VehicleDataService();

  String selectedSort = "date";
  List<String> selectedCategories = [];
  DateTimeRange? selectedDateRange;
  String? selectedVehicleId;

  late String uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
  }

  Map<String, String> vehicleNames = {};

  // --------------------------------------------------------------------------
  // 🔵 USE NEW BACKEND FUNCTION BUT KEEP ORIGINAL UI
  // --------------------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> _getFilteredRecords() {
    return serviceRecordDB.getServiceRecords(
      uid: uid,
      category: selectedCategories.length == 1
          ? selectedCategories.first
          : null,
      vehicleId: selectedVehicleId == "All" ? null : selectedVehicleId,
      dateRange: selectedDateRange,
      sortBy: selectedSort,
    );
  }

  // --------------------------------------------------------------------------
  // 🔵 RESET
  // --------------------------------------------------------------------------
  void _resetFilters() {
    setState(() {
      selectedSort = "date";
      selectedCategories.clear();
      selectedDateRange = null;
      selectedVehicleId = null;
    });
  }

  // --------------------------------------------------------------------------
  // 🔵 CATEGORY ICONS (KEPT FROM ORIGINAL)
  // --------------------------------------------------------------------------
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Maintenance':
        return Icons.settings;
      case 'Toll':
        return Icons.traffic;
      case 'Parking':
        return Icons.local_parking;
      case 'Car Wash':
        return Icons.local_car_wash;
      case 'Insurance':
        return Icons.security;
      case 'Road Tax':
        return Icons.receipt_long;
      case 'Installment':
        return Icons.credit_card;
      case 'Makeup':
        return Icons.brush;
      default:
        return Icons.build;
    }
  }

  // --------------------------------------------------------------------------
  // 🔵 FILTER BOTTOM SHEET (FULL ORIGINAL VERSION)
  // --------------------------------------------------------------------------
  Future<void> _showFilterDialog() async {
    List<String> tempCategories = List.from(selectedCategories);
    String tempSort = selectedSort;
    DateTimeRange? tempDateRange = selectedDateRange;
    String? tempVehicleId = selectedVehicleId;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Center(
                    child: Text(
                      "Filter Service Records",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // SORT SECTION
                  _sectionHeader(Icons.sort, "Sort by"),
                  DropdownButtonFormField<String>(
                    value: tempSort,
                    decoration: _dropdownDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: 'date',
                        child: Text("Date (Newest first)"),
                      ),
                      DropdownMenuItem(
                        value: 'amount',
                        child: Text("Amount (Highest first)"),
                      ),
                    ],
                    onChanged: (v) =>
                        setModalState(() => tempSort = v ?? "date"),
                  ),
                  const SizedBox(height: 16),

                  // CATEGORY SECTION
                  _sectionHeader(Icons.category, "Category"),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (var cat in [
                        'Maintenance',
                        'Toll',
                        'Parking',
                        'Car Wash',
                        'Insurance',
                        'Road Tax',
                        'Installment',
                        'Makeup',
                      ])
                        FilterChip(
                          label: Text(cat),
                          selected: tempCategories.contains(cat),
                          selectedColor: Colors.blue,
                          onSelected: (v) {
                            setModalState(() {
                              if (v)
                                tempCategories.add(cat);
                              else
                                tempCategories.remove(cat);
                            });
                          },
                        ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // DATE RANGE
                  _sectionHeader(Icons.calendar_month, "Date Range"),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_month),
                    label: Text(
                      tempDateRange == null
                          ? "Select Date Range"
                          : "${DateFormat('MMM d').format(tempDateRange!.start)} → ${DateFormat('MMM d, yyyy').format(tempDateRange!.end)}",
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: tempDateRange,
                      );
                      if (picked != null) {
                        setModalState(() => tempDateRange = picked);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // VEHICLE DROPDOWN
                  _sectionHeader(Icons.directions_car, "Vehicle"),
                  StreamBuilder(
                    stream: vehicleService.vehiclesStream,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final vehicles = snapshot.data!;
                      vehicleNames.clear();
                      for (var v in vehicles) {
                        vehicleNames[v.vehicleId] =
                            "${v.brand} ${v.model} (${v.plateNumber})";
                      }

                      return DropdownButtonFormField<String>(
                        value: tempVehicleId ?? "All",
                        decoration: _dropdownDecoration(),
                        items: [
                          const DropdownMenuItem(
                            value: "All",
                            child: Text("All Vehicles"),
                          ),
                          ...vehicles.map(
                            (v) => DropdownMenuItem(
                              value: v.vehicleId,
                              child: Text(vehicleNames[v.vehicleId]!),
                            ),
                          ),
                        ],
                        onChanged: (v) =>
                            setModalState(() => tempVehicleId = v),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // APPLY BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        label: const Text(
                          "Reset",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          setModalState(() {
                            tempSort = "date";
                            tempCategories.clear();
                            tempDateRange = null;
                            tempVehicleId = null;
                          });
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text("Apply"),
                        onPressed: () {
                          setState(() {
                            selectedSort = tempSort;
                            selectedCategories = tempCategories;
                            selectedDateRange = tempDateRange;
                            selectedVehicleId = tempVehicleId;
                          });
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 5),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --------------------------------------------------------------------------
  // 🔵 BUILD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Service Records",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue,
      ),

      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddServiceRecordPage(userDoc: widget.userDoc),
            ),
          );
        },
      ),

      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // FILTER BUTTON + RESET
            Row(
              children: [
                Expanded(
                  child: _buildButton(
                    Icons.filter_list,
                    "Filter",
                    _showFilterDialog,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text("Reset"),
                  onPressed: _resetFilters,
                ),
              ],
            ),

            const SizedBox(height: 10),

            // ACTIVE FILTERS CHIPS
            if (selectedCategories.isNotEmpty ||
                selectedDateRange != null ||
                (selectedVehicleId != null && selectedVehicleId != "All"))
              Wrap(
                spacing: 8,
                children: [
                  if (selectedCategories.isNotEmpty)
                    Chip(label: Text(selectedCategories.join(", "))),
                  if (selectedDateRange != null)
                    Chip(
                      label: Text(
                        "${DateFormat('MMM d').format(selectedDateRange!.start)} → ${DateFormat('MMM d').format(selectedDateRange!.end)}",
                      ),
                    ),
                  if (selectedVehicleId != null && selectedVehicleId != "All")
                    Chip(label: Text(vehicleNames[selectedVehicleId]!)),
                ],
              ),

            const SizedBox(height: 10),

            // LIST OF RECORDS
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getFilteredRecords(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final records = snapshot.data!;
                  if (records.isEmpty) {
                    return const Center(child: Text("No records found"));
                  }

                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, i) {
                      final record = records[i];

                      final category = record["category"] ?? "Unknown";
                      final date = record["date"] ?? "-";
                      final amount = (record["amount"] ?? 0).toDouble();

                      return Card(
                        elevation: 3,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ServiceRecordDetailsPage(record: record),
                              ),
                            );
                          },
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(
                              _getCategoryIcon(category),
                              color: Colors.blue.shade700,
                            ),
                          ),
                          title: Text(
                            category,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(date),
                          trailing: Text(
                            "RM${amount.toStringAsFixed(2)}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // FILTER BUTTON
  Widget _buildButton(IconData icon, String label, VoidCallback onPressed) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue,
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
