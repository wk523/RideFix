import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/Fuel&MileageAnalytics/FuelAnalyticsController.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceController.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Note: You must create this file and implement the required method.
import 'package:ridefix/View/Fuel&MileageAnalytics/AddFuelEntry.dart';
import 'package:ridefix/View/Fuel&MileageAnalytics/FuelEntryDetails.dart';

class FuelEntryPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const FuelEntryPage({super.key, required this.userDoc});

  @override
  State<FuelEntryPage> createState() => _FuelEntryPageState();
}

class _FuelEntryPageState extends State<FuelEntryPage> {
  final FuelEntryDatabase fuelEntryDB = FuelEntryDatabase();
  final VehicleDataService vehicleService = VehicleDataService();

  // State for Filters
  String selectedSort = "date"; // Can be 'date' or 'amount'
  DateTimeRange? selectedDateRange;
  String? selectedVehicleId; // Null for 'All'

  late String uid;

  // Map to store vehicleId -> vehicleName (Brand Model (Plate))
  // This map will be populated by the StreamBuilder in the build method.
  Map<String, String> vehicleNames = {};

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
  }

  // --------------------------------------------------------------------------
  // 🔵 BACKEND STREAM FUNCTION
  // --------------------------------------------------------------------------
  Stream<List<Map<String, dynamic>>> _getFilteredRecords() {
    return fuelEntryDB.getFuelEntries(
      uid: uid,
      vehicleId: selectedVehicleId == "All" ? null : selectedVehicleId,
      dateRange: selectedDateRange,
      sortBy: selectedSort,
    );
  }

  // --------------------------------------------------------------------------
  // 🔵 RESET FILTERS
  // --------------------------------------------------------------------------
  void _resetFilters() {
    setState(() {
      selectedSort = "date";
      selectedDateRange = null;
      selectedVehicleId = null;
    });
  }

  // --------------------------------------------------------------------------
  // 🔵 FILTER BOTTOM SHEET
  // --------------------------------------------------------------------------
  Future<void> _showFilterDialog() async {
    String tempSort = selectedSort;
    DateTimeRange? tempDateRange = selectedDateRange;
    String? tempVehicleId = selectedVehicleId;

    BoxDecoration _dateRangeDecoration(BuildContext context) {
      return BoxDecoration(
        border: Border.all(color: Colors.grey, width: 1.0),
        borderRadius: BorderRadius.circular(12),
      );
    }

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
              // Use viewInsets.bottom for keyboard padding, but remove
              // excessive bottom padding when keyboard is hidden.
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                // Use ternary operator to conditionally add padding when keyboard is NOT open (viewInsets.bottom == 0)
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? MediaQuery.of(context).viewInsets.bottom + 16
                    : 16,
              ),
              child: Column(
                // ⭐️ FIX: Use MainAxisSize.min to size the column to its children ⭐️
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
                      "Filter Fuel Entries",
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
                    initialValue: tempSort,
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

                  // DATE RANGE
                  _sectionHeader(Icons.calendar_month, "Date Range"),
                  Container(
                    width: double.infinity,
                    height: 58,
                    decoration: _dateRangeDecoration(context),
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        alignment: Alignment.centerLeft,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: Colors.black87,
                      ),
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
                        // Use a safe null check for `picked` and update state
                        if (picked != null) {
                          setModalState(() => tempDateRange = picked);
                        }
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // VEHICLE DROPDOWN (Now relies on the map being updated in the main build)
                  _sectionHeader(Icons.directions_car, "Vehicle"),
                  DropdownButtonFormField<String>(
                    // Ensure initialValue is one of the valid values or null
                    initialValue: tempVehicleId ?? "All",
                    decoration: _dropdownDecoration(),
                    items: [
                      const DropdownMenuItem(
                        value: "All",
                        child: Text("All Vehicles"),
                      ),
                      // Only show vehicles that were loaded into the map
                      ...vehicleNames.entries.map(
                            (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(entry.value),
                        ),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => tempVehicleId = v),
                  ),

                  const SizedBox(height: 24),

                  // APPLY BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                        ),
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
                            tempDateRange = null;
                            tempVehicleId = "All"; // Reset to "All" instead of null
                          });
                        },
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text("Apply"),
                        onPressed: () {
                          // Apply filter changes to the main state
                          setState(() {
                            selectedSort = tempSort;
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

  // --------------------------------------------------------------------------
  // 🔵 HELPER WIDGETS
  // --------------------------------------------------------------------------
  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 5),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

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

  // --------------------------------------------------------------------------
  // 🔵 BUILD
  // --------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Fuel Entries",
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
              builder: (context) => AddFuelEntryPage(userDoc: widget.userDoc),
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
                  onPressed: _resetFilters,
                  child: const Text("Reset"),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ACTIVE FILTERS CHIPS
            if (selectedDateRange != null ||
                (selectedVehicleId != null && selectedVehicleId != "All"))
              Wrap(
                spacing: 8,
                children: [
                  if (selectedDateRange != null)
                    Chip(
                      label: Text(
                        "${DateFormat('MMM d').format(selectedDateRange!.start)} → ${DateFormat('MMM d').format(selectedDateRange!.end)}",
                      ),
                    ),
                  if (selectedVehicleId != null && selectedVehicleId != "All")
                    // Safe access with null check
                    Chip(label: Text(vehicleNames[selectedVehicleId] ?? 'N/A')),
                ],
              ),

            const SizedBox(height: 10),

            // 💡 FIX START: Wrap the main content with a StreamBuilder for vehicle data
            Expanded(
              child: StreamBuilder(
                stream: vehicleService.vehiclesStream,
                builder: (context, vehicleSnapshot) {
                  if (vehicleSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 1. Update the vehicleNames map once vehicle data is ready
                  if (vehicleSnapshot.hasData) {
                    vehicleNames.clear();
                    for (var v in vehicleSnapshot.data!) {
                      // Note: Assuming 'v' is a class/object with vehicleId, brand, model, plateNumber
                      vehicleNames[v.vehicleId] =
                          "${v.brand} ${v.model} (${v.plateNumber})";
                    }
                  } else {
                    vehicleNames.clear(); // Clear if no vehicle data
                  }

                  // 2. Now stream the fuel records, relying on the updated vehicleNames map
                  return StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _getFilteredRecords(),
                    builder: (context, fuelSnapshot) {
                      if (fuelSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (fuelSnapshot.hasError) {
                        print(
                          "Error fetching fuel entries: ${fuelSnapshot.error}",
                        );
                        return Center(
                          child: Text("Error: ${fuelSnapshot.error}"),
                        );
                      }

                      final records = fuelSnapshot.data ?? [];
                      if (records.isEmpty) {
                        return const Center(
                          child: Text("No fuel entries found"),
                        );
                      }

                      return ListView.builder(
                        itemCount: records.length,
                        itemBuilder: (context, i) {
                          final record = records[i];

                          final fuelType = record["fuelType"] ?? "Unknown Fuel";
                          final date = record["date"] ?? "-";
                          final amount = (record["amount"] ?? 0).toDouble();

                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: ListTile(
                              onTap: () {
                                final String? vehicleId = record["vehicleId"];

                                // Get the plate name from the pre-loaded map
                                final String? plate = vehicleNames[vehicleId];

                                // This is now safe, as vehicleNames was populated
                                // before this builder ran.
                                final enrichedRecord = {
                                  ...record,
                                  "plateNumber": plate ?? "N/A",
                                };

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => FuelEntryDetailsPage(
                                      record: enrichedRecord,
                                    ),
                                  ),
                                );
                              },
                              leading: CircleAvatar(
                                backgroundColor: Colors.orange.shade100,
                                child: Icon(
                                  Icons.local_gas_station,
                                  color: Colors.orange.shade700,
                                ),
                              ),
                              title: Text(
                                fuelType,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(date),
                              trailing: Text(
                                "RM${amount.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            // 💡 FIX END
          ],
        ),
      ),
    );
  }
}
