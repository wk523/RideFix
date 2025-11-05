import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';
import 'package:ridefix/ServiceRecord/AddServiceRecord.dart';
import 'package:ridefix/ServiceRecord/ServiceRecordDetails.dart';

class ServiceRecordPage extends StatefulWidget {
  const ServiceRecordPage({super.key});

  @override
  State<ServiceRecordPage> createState() => _ServiceRecordPageState();
}

class _ServiceRecordPageState extends State<ServiceRecordPage> {
  String selectedSort = '';
  List<String> selectedCategories = [];
  DateTimeRange? selectedDateRange;
  String? selectedVehicleId;

  final String userId = 'weikit523'; // Hardcoded for testing
  final VehicleDataService vehicleDataService = VehicleDataService();

  // Map to store vehicleId -> vehicle name
  Map<String, String> vehicleNames = {};

  Stream<QuerySnapshot> _getFilteredRecords() {
    Query query = FirebaseFirestore.instance
        .collection('ServiceRecord')
        .where('userId', isEqualTo: userId);

    // Category filter
    if (selectedCategories.isNotEmpty) {
      query = query.where('category', whereIn: selectedCategories);
    }

    // Date range filter
    if (selectedDateRange != null) {
      final startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(selectedDateRange!.start);
      final endDate = DateFormat('yyyy-MM-dd').format(selectedDateRange!.end);
      query = query
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate);
    }

    // Vehicle filter
    if (selectedVehicleId != null && selectedVehicleId != 'All') {
      query = query.where('vehicleId', isEqualTo: selectedVehicleId);
    }

    // Sorting
    if (selectedSort == 'amount') {
      query = query.orderBy('amount', descending: true);
    } else if (selectedSort == 'date') {
      query = query.orderBy('date', descending: true);
    }

    return query.snapshots();
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

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text(
                'Filters',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // --- Sort ---
                    const Text(
                      'Sort by',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    DropdownButton<String>(
                      value: tempSort.isEmpty ? null : tempSort,
                      hint: const Text('Select sort option'),
                      isExpanded: true,
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
                    const Divider(),

                    // --- Category ---
                    const Text(
                      'Category',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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
                    const Divider(),

                    // --- Date Range ---
                    const Text(
                      'Date Range',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month),
                      label: Text(
                        tempDateRange == null
                            ? 'Select Range'
                            : '${DateFormat('MMM d').format(tempDateRange!.start)} → ${DateFormat('MMM d, yyyy').format(tempDateRange!.end)}',
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
                                useMaterial3: false, // Keep old layout
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
                        if (picked != null)
                          setModalState(() => tempDateRange = picked);
                      },
                    ),
                    const Divider(),

                    // --- Vehicle Filter ---
                    const Text(
                      'Vehicle',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    StreamBuilder(
                      stream: vehicleDataService.vehiclesStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          );
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

                        return DropdownButton<String>(
                          value: tempVehicleId,
                          hint: const Text('Select vehicle'),
                          isExpanded: true,
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    setModalState(() {
                      tempSort = '';
                      tempCategories.clear();
                      tempDateRange = null;
                      tempVehicleId = null;
                    });
                  },
                  child: const Text(
                    'Reset',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedSort = tempSort;
                      selectedCategories = tempCategories;
                      selectedDateRange = tempDateRange;
                      selectedVehicleId = tempVehicleId;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Apply',
                    style: TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Records'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddServiceRecordPage(),
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
              child: StreamBuilder<QuerySnapshot>(
                stream: _getFilteredRecords(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No service records found.'),
                    );
                  }

                  final records = snapshot.data!.docs;
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
                            final doc = records[index];
                            final record = doc.data() as Map<String, dynamic>;

                            // Safely read fields from Firestore doc
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
                                          _getCategoryIcon(
                                            record['category'] ?? '',
                                          ),
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
                                              record['category'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              record['date'] ?? '-',
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
                                          'RM ${(record['amount'] ?? 0).toString()}',
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
