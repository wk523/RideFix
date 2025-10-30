import 'package:flutter/material.dart';
// NOTE: I am referencing the service instance now correctly based on your provided path/name.
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';

// --- Vehicle List Page Widget ---
class VehicleListPage extends StatelessWidget {
  const VehicleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Scaffold provides the grey background and overall structure
    return Scaffold(
      backgroundColor: Colors.grey[200],

      // Blue AppBar matching the screenshot
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Handle back navigation or menu open
          },
        ),
        title: const Text(
          'Your Vehicles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      // FIX: Use FutureBuilder to wait for Firebase initialization to complete.
      body: FutureBuilder(
        future: vehicleDataService.initializationComplete,
        builder: (context, snapshot) {
          // 1. Show Loading while waiting for Firebase/Auth initialization
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 2. Handle Initialization Errors
          if (snapshot.hasError) {
            // This catches the 'CRITICAL ERROR' thrown in the service file
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

          // 3. Once initialized, listen to the vehicle stream
          // The StreamBuilder now runs only after the service is ready.
          return StreamBuilder<List<Vehicle>>(
            stream: vehicleDataService.vehiclesStream,
            builder: (context, streamSnapshot) {
              // Show Loading while waiting for initial data fetch (which is fast,
              // but necessary for the first network request).
              if (streamSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              // Handle errors during data fetching (if connection succeeded but query failed)
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

              // Display the list of vehicles
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

      // Floating Action Button for adding a new vehicle
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to the Vehicle Registration Page
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

// --- Helper Widget for the Vehicle Card UI (Kept the same) ---
class VehicleListCard extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleListCard({super.key, required this.vehicle});

  @override
  Widget build(BuildContext context) {
    // Use an InkWell for tap detection (to go to the details page)
    return InkWell(
      onTap: () {
        // Handle navigation to VehicleDetailsPage
        print('Tapped on ${vehicle.model}');
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
            // Vehicle Image (Left side)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                vehicle.imageUrl,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Icon(Icons.directions_car, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 15.0),

            // Vehicle Details (Right side)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Model Title (e.g., Honda Civic)
                  Text(
                    vehicle.model,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),

                  // Plate Number and Mileage Info
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
