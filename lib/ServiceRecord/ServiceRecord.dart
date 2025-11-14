import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/ServiceRecord/ServiceRecordDatabase.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';
import 'package:ridefix/ServiceRecord/AddServiceRecord.dart';
import 'package:ridefix/ServiceRecord/ServiceRecordDetails.dart';

class ServiceRecordPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const ServiceRecordPage({super.key, required this.userDoc});

  @override
  State<ServiceRecordPage> createState() => _ServiceRecordPageState();
}

class _ServiceRecordPageState extends State<ServiceRecordPage> {
  String selectedSort = '';
  List<String> selectedCategories = [];
  DateTimeRange? selectedDateRange;
  String? selectedVehicleId;
  final ServiceRecordDatabase serviceDb = ServiceRecordDatabase();

  final VehicleDataService vehicleDataService = VehicleDataService();
  late final String uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
  }

  // Map to store vehicleId -> vehicle name
  Map<String, String> vehicleNames = {};

  Stream<List<Map<String, dynamic>>> _getFilteredRecords() {
    return serviceDb.streamFilteredServiceRecords(
      uid: uid,
      category: selectedCategories.isEmpty
          ? null
          : (selectedCategories.length == 1 ? selectedCategories.first : null),

      dateRange: selectedDateRange,
      sortBy: selectedSort == 'amount' ? 'Amount' : 'Date',
    );
  }

  void _resetFilters() {
    setState(() {
      selectedSort = '';
      selectedCategories.clear();
      selectedDateRange = null;
      selectedVehicleId = null;
    });
  }

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
        return Icons.miscellaneous_services;
    }
  }

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

                  // Sort Section
                  _sectionHeader(Icons.sort, "Sort by"),
                  DropdownButtonFormField<String>(
                    value: tempSort.isEmpty ? null : tempSort,
                    hint: const Text('Select sort option'),
                    decoration: _dropdownDecoration(),
                    items: const [
                      DropdownMenuItem(
                        value: 'date',
                        child: Text('Date (Newest first)'),
                      ),
                      DropdownMenuItem(
                        value: 'amount',
                        child: Text('Amount (Highest first)'),
                      ),
                    ],
                    onChanged: (val) =>
                        setModalState(() => tempSort = val ?? ''),
                  ),
                  const SizedBox(height: 16),

                  // Category Section
                  _sectionHeader(Icons.category, "Category"),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
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
                          labelStyle: TextStyle(
                            color: tempCategories.contains(cat)
                                ? Colors.white
                                : Colors.black,
                            fontWeight: FontWeight.w500,
                          ),
                          selected: tempCategories.contains(cat),
                          selectedColor: Colors.blue.shade600,
                          backgroundColor: Colors.grey[200],
                          onSelected: (v) {
                            setModalState(() {
                              if (v) {
                                tempCategories.add(cat);
                              } else {
                                tempCategories.remove(cat);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Date Range
                  // 📅 Date Range Section
                  const Text(
                    'Date Range',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.blue.shade50,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.shade300),
                      ),
                    ),
                    icon: Icon(
                      Icons.calendar_month,
                      color: Colors.blue.shade700,
                    ),
                    label: Text(
                      tempDateRange == null
                          ? 'Select Date Range'
                          : '${DateFormat('MMM d').format(tempDateRange!.start)} → ${DateFormat('MMM d, yyyy').format(tempDateRange!.end)}',
                      style: TextStyle(
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDateRangePicker(
                        context: context,
                        initialDateRange:
                            tempDateRange ??
                            DateTimeRange(
                              start: now.subtract(const Duration(days: 7)),
                              end: now,
                            ),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              useMaterial3: false, // ✅ Keep old layout
                              colorScheme: ColorScheme.light(
                                primary: Colors
                                    .blue
                                    .shade700, // Header & selection color
                                onPrimary: Colors.white, // Text on header
                                onSurface: Colors.black87, // Calendar text
                                surface: Colors.white,
                              ),
                              dialogBackgroundColor: Colors.white,
                              textButtonTheme: TextButtonThemeData(
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.blue.shade700,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );

                      if (picked != null) {
                        setModalState(() => tempDateRange = picked);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // Vehicle Filter
                  _sectionHeader(Icons.directions_car, "Vehicle"),
                  StreamBuilder(
                    stream: vehicleDataService.vehiclesStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text('No vehicles found.');
                      }

                      final vehicles = snapshot.data!;
                      vehicleNames.clear();
                      for (var v in vehicles) {
                        vehicleNames[v.vehicleId] =
                            '${v.brand} ${v.model} (${v.plateNumber})';
                      }

                      return DropdownButtonFormField<String>(
                        value: tempVehicleId,
                        hint: const Text('Select vehicle'),
                        decoration: _dropdownDecoration(),
                        items: [
                          const DropdownMenuItem(
                            value: 'All',
                            child: Text('All Vehicles'),
                          ),
                          ...vehicles.map(
                            (v) => DropdownMenuItem(
                              value: v.vehicleId,
                              child: Text(
                                '${v.brand} ${v.model} (${v.plateNumber})',
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) =>
                            setModalState(() => tempVehicleId = val),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        label: const Text(
                          "Reset",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () {
                          setModalState(() {
                            tempSort = '';
                            tempCategories.clear();
                            tempDateRange = null;
                            tempVehicleId = null;
                          });
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                        ),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text(
                          "Apply",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue.shade600, size: 20),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Service Records',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddServiceRecordPage(userDoc: widget.userDoc),
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildButton(
                    Icons.filter_list,
                    'Filter',
                    _showFilterDialog,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red.shade700,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: const Text(
                      'Reset',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    onPressed: _resetFilters,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Active filter chips
            if (selectedSort.isNotEmpty ||
                selectedCategories.isNotEmpty ||
                selectedDateRange != null ||
                (selectedVehicleId != null && selectedVehicleId != 'All'))
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8.0,
                children: [
                  if (selectedSort.isNotEmpty)
                    Chip(label: Text('Sort: $selectedSort')),
                  if (selectedCategories.isNotEmpty)
                    Chip(
                      label: Text('Category: ${selectedCategories.join(', ')}'),
                    ),
                  if (selectedDateRange != null)
                    Chip(
                      label: Text(
                        '${DateFormat('MMM d').format(selectedDateRange!.start)} → '
                        '${DateFormat('MMM d, yyyy').format(selectedDateRange!.end)}',
                      ),
                    ),
                  if (selectedVehicleId != null && selectedVehicleId != 'All')
                    Chip(
                      label: Text(
                        'Vehicle: ${vehicleNames[selectedVehicleId] ?? selectedVehicleId}',
                      ),
                    ),
                ],
              ),
            const SizedBox(height: 10),

            // Service record list
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getFilteredRecords(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No service records found.'),
                    );
                  }

                  final records = snapshot.data!;

                  return Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Showing ${records.length} record(s)',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),

                      Expanded(
                        child: ListView.builder(
                          itemCount: records.length,
                          itemBuilder: (context, index) {
                            final record = records[index];

                            // Safely read fields
                            final category = (record['category'] ?? 'Unknown')
                                .toString();
                            final date = (record['date'] ?? '-').toString();
                            final description = (record['description'] ?? '')
                                .toString();

                            final amountNum =
                                double.tryParse(
                                  record['amount']?.toString() ?? '',
                                ) ??
                                0.0;
                            final formattedAmount = amountNum.toStringAsFixed(
                              2,
                            );

                            return InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ServiceRecordDetailsPage(
                                          record: record,
                                        ),
                                  ),
                                );
                              },
                              child: Card(
                                elevation: 3,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                    horizontal: 12.0,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      CircleAvatar(
                                        backgroundColor: Colors.blue.shade100,
                                        child: Icon(
                                          _getCategoryIcon(category),
                                          color: Colors.blue.shade700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              category,
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              date,
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),

                                      Padding(
                                        padding: const EdgeInsets.only(
                                          left: 12.0,
                                        ),
                                        child: Text(
                                          'RM$formattedAmount',
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Filter button widget (no Expanded inside)
  Widget _buildButton(IconData icon, String label, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.blue.shade800,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
