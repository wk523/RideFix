import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ridefix/View/VehicleMaintenance/UpdateVehicle.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceController.dart';

import '../../Model/vehicle_maintenance_model.dart';

class VehicleDetailsPage extends StatefulWidget {
  final String vehicleId;
  final String uid;

  const VehicleDetailsPage({
    super.key,
    required this.vehicleId,
    required this.uid,
  });

  @override
  State<VehicleDetailsPage> createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  bool _forceRefresh = false;

  // 🚀 OPTIMIZATION STEP 1: Declare a variable to hold the Future result.
  late Future<Map<String, dynamic>> _analyticsFuture;

  // 🚀 OPTIMIZATION STEP 2: Initialize the Future only once in initState.
  @override
  void initState() {
    super.initState();
    _analyticsFuture = _fetchAnalyticsData();
  }

  // Method to fetch ALL analytics data concurrently (same logic, better usage)
  Future<Map<String, dynamic>> _fetchAnalyticsData() async {
    final serviceCountFuture = vehicleDataService.getServiceCount(
      widget.vehicleId,
      widget.uid,
    );
    final fuelCountFuture = vehicleDataService.getFuelEntryCount(
      widget.vehicleId,
      widget.uid,
    );
    final expenseSummaryFuture = vehicleDataService.getExpenseSummary(
      widget.vehicleId,
      widget.uid,
    );

    final results = await Future.wait([
      serviceCountFuture,
      fuelCountFuture,
      expenseSummaryFuture,
    ]);

    final expenseSummary = results[2] as Map<String, double>;

    return {
      'serviceHistoryCount': results[0],
      'fuelEntriesCount': results[1],
      'totalExpenses': expenseSummary['totalExpenses'],
      'avgMonthlyExpenses': expenseSummary['avgMonthlyExpenses'],
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      // The key triggers a full State rebuild, which re-runs initState and the analytics fetch
      key: ValueKey(_forceRefresh),
      stream: FirebaseFirestore.instance
          .collection('Vehicle')
          .doc(widget.vehicleId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: Text('Vehicle not found')));
        }

        final vehicle = Vehicle.fromFirestore(snapshot.data!);
        return _buildVehicleDetailUI(context, vehicle);
      },
    );
  }

  Widget _buildVehicleDetailUI(BuildContext context, Vehicle vehicle) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          vehicle.plateNumber,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        children: [
          // --- Vehicle Image ---
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Image.network(
                vehicle.imageUrl,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[300],
                  child: const Center(
                    child: Icon(
                      Icons.directions_car,
                      color: Colors.grey,
                      size: 60,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12.0),

          // --- Edit & Delete Buttons ---
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey, size: 24),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          UpdateVehiclePage(vehicleDetails: vehicle),
                    ),
                  );

                  if (result == true) {
                    // 🚀 OPTIMIZATION STEP 3: Re-initialize the Future AND then trigger the rebuild
                    setState(() {
                      _analyticsFuture = _fetchAnalyticsData();
                      _forceRefresh = !_forceRefresh;
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey, size: 24),
                onPressed: () async {
                  await vehicleDataService.deleteVehicle(context, vehicle);
                },
              ),
            ],
          ),

          const SizedBox(height: 8.0),

          // --- Vehicle Details Card ---
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      vehicle.brand,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(width: 5.0),
                    Text(
                      vehicle.model,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12.0),
                DetailRow(
                  label: 'Vehicle Plate Number',
                  value: vehicle.plateNumber,
                ),
                DetailRow(label: 'Color', value: vehicle.color),
                DetailRow(
                  label: 'Manufacture Year',
                  value: vehicle.manYear.toString(),
                ),
                DetailRow(label: 'Mileage', value: '${vehicle.mileage} km'),
                DetailRow(
                  label: 'Road Tax Expiry',
                  value: vehicle.roadTaxExpired,
                ),
                const SizedBox(height: 10),
                const Divider(),
                const SizedBox(height: 10),

                // --- Analytics Data (Dynamic) ---
                FutureBuilder<Map<String, dynamic>>(
                  // 🚀 OPTIMIZATION STEP 4: Use the initialized variable here.
                  // It will only call _fetchAnalyticsData() once unless the key forces a rebuild.
                  future: _analyticsFuture,
                  builder: (context, analyticsSnapshot) {
                    if (analyticsSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }

                    final data = analyticsSnapshot.data ?? {};
                    final serviceCount =
                        data['serviceHistoryCount'] as int? ?? 0;
                    final fuelCount = data['fuelEntriesCount'] as int? ?? 0;
                    final totalExpenses =
                        data['totalExpenses'] as double? ?? 0.0;
                    final avgMonthlyExpenses =
                        data['avgMonthlyExpenses'] as double? ?? 0.0;

                    if (analyticsSnapshot.hasError) {
                      return const DetailRow(
                        label: 'Analytics Error',
                        value: 'Data failed to load',
                        valueColor: Colors.red,
                      );
                    }

                    return Column(
                      children: [
                        DetailRow(
                          label: 'Service History Count',
                          value: serviceCount.toString(),
                          valueColor: serviceCount > 0
                              ? Colors.blue
                              : Colors.black,
                        ),
                        DetailRow(
                          label: 'Fuel Entries Count',
                          value: fuelCount.toString(),
                          valueColor: fuelCount > 0
                              ? Colors.blue
                              : Colors.black,
                        ),
                        DetailRow(
                          label: 'Total Expenses (RM)',
                          value: totalExpenses.toStringAsFixed(2),
                          valueColor: Colors.red,
                        ),
                        DetailRow(
                          label: 'Avg Monthly Expenses (RM)',
                          value: avgMonthlyExpenses.toStringAsFixed(2),
                          valueColor: Colors.red,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
// --- Helper Widget ---

class DetailRow extends StatelessWidget {
  final String label;

  final String value;

  final Color valueColor;

  const DetailRow({
    required this.label,

    required this.value,

    this.valueColor = Colors.black,

    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,

        children: [
          Text(
            '$label:',

            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),

          Flexible(
            child: Text(
              value,

              textAlign: TextAlign.end,

              style: TextStyle(
                fontSize: 16,

                fontWeight: FontWeight.bold,

                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
