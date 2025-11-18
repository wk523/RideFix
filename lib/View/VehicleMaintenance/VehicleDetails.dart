import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ridefix/View/VehicleMaintenance/UpdateVehicle.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';

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
  // 🔁 Used to trigger rebuild when coming back from update page
  bool _forceRefresh = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      key: ValueKey(_forceRefresh), // ensures rebuild when toggled
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
    // ✅ Hardcoded values (you can later connect to Firestore or analytics)
    const serviceHistoryCount = 10;
    const fuelEntriesCount = 20;
    const totalExpenses = 3010.00;
    const avgMonthlyExpenses = 1505.00;

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
                fit: BoxFit.contain,
                width: double.infinity,
                height: 220,
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

                  // ✅ After update, rebuild StreamBuilder manually
                  if (result == true) {
                    setState(() => _forceRefresh = !_forceRefresh);
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
                SizedBox(height: 10),
                DetailRow(label: 'Service History Count', value: '10'),
                DetailRow(label: 'Fuel Entries Count', value: '20'),
                DetailRow(label: 'Total Expenses (RM)', value: '3010.00'),
                DetailRow(label: 'Avg Monthly Expenses (RM)', value: '1505.00'),
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
