import 'package:flutter/material.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';
import 'package:ridefix/VehicleMaintenance/VehicleDetails.dart';
import 'package:ridefix/VehicleMaintenance/VehicleRegistration.dart';

// --- Vehicle List Page Widget (Now Stateful) ---
class VehicleListPage extends StatefulWidget {
  const VehicleListPage({super.key});

  @override
  State<VehicleListPage> createState() => _VehicleListPageState();
}

class _VehicleListPageState extends State<VehicleListPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Your Vehicles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      // --- FutureBuilder to wait for initialization ---
      body: FutureBuilder(
        future: vehicleDataService.initializationComplete,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Failed to load application data.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Error: ${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // --- StreamBuilder for vehicles list ---
          return StreamBuilder<List<Vehicle>>(
            stream: vehicleDataService.vehiclesStream,
            builder: (context, streamSnapshot) {
              if (streamSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (streamSnapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading vehicles: ${streamSnapshot.error}',
                  ),
                );
              }

              final vehicles = streamSnapshot.data ?? [];

              if (vehicles.isEmpty) {
                return const Center(
                  child: Text(
                    'No vehicles registered. Tap + to add one!',
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 10.0,
                ),
                itemCount: vehicles.length,
                itemBuilder: (context, index) {
                  final vehicle = vehicles[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: VehicleListCard(vehicle: vehicle),
                  );
                },
              );
            },
          );
        },
      ),

      // --- Floating Action Button ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          // Wait for the registration page to complete
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const VehicleRegistrationPage(),
            ),
          );

          // Refresh the list when coming back
          setState(() {});
        },
      ),
    );
  }
}

extension on VehicleDataService {
  Future<Object?>? get initializationComplete => null;
}

// --- Helper Widget for the Vehicle Card UI ---
class VehicleListCard extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleListCard({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        // ✅ Navigate to Vehicle Details Page
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VehicleDetailsPage(
              vehicleId: vehicle.vehicleId,
              userId: '', // ✅ This must not be empty
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10.0),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ✅ Vehicle Image (Fix: use Image.network instead of Image.asset)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: vehicle.imageUrl.isNotEmpty
                  ? Image.network(
                      vehicle.imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 80,
                        height: 80,
                        color: Colors.grey[300],
                        child: const Icon(
                          Icons.directions_car,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.directions_car,
                        color: Colors.grey,
                      ),
                    ),
            ),
            const SizedBox(width: 15.0),

            // Vehicle Details (Right side)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        vehicle.brand,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 2.0),
                      Text(
                        vehicle.model,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8.0),
                  Row(
                    children: [
                      const Icon(Icons.numbers, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.plateNumber,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Icon(Icons.speed, size: 16, color: Colors.blue),
                      const SizedBox(width: 4),
                      Text(
                        vehicle.mileage.toString(),
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
