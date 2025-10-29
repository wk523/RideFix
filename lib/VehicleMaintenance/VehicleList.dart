import 'package:flutter/material.dart';

// --- 1. Data Model for a Vehicle ---
class Vehicle {
  final String model;
  final String licensePlate;
  final String chassisNumber;
  final String imageUrl;

  Vehicle({
    required this.model,
    required this.licensePlate,
    required this.chassisNumber,
    required this.imageUrl,
  });
}

// --- 2. Sample Data (To populate the list) ---
final List<Vehicle> mockVehicles = [
  Vehicle(
    model: 'Honda Civic',
    licensePlate: 'XXX 1234',
    chassisNumber: '2409190',
    // NOTE: Replace with your actual asset path
    imageUrl: 'assets/honda_civic_1.png',
  ),
  Vehicle(
    model: 'Toyota Supra',
    licensePlate: 'XXX 0000',
    chassisNumber: '2402427',
    // NOTE: Replace with your actual asset path
    imageUrl: 'assets/toyota_supra.png',
  ),
  Vehicle(
    model: 'Honda Civic',
    licensePlate: 'XXX 0001',
    chassisNumber: '1025360',
    // NOTE: Replace with your actual asset path
    imageUrl: 'assets/honda_civic_2.png',
  ),
];

// ------------------------------------------------------------------
// --- 3. Vehicle List Screen Widget (The full page layout) ---
// ------------------------------------------------------------------
class VehicleListPage extends StatelessWidget {
  const VehicleListPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Note: The Scaffold's grey background should be set by the MaterialApp
    // in main.dart (scaffoldBackgroundColor: Colors.grey[200]).
    return Scaffold(
      // The blue header section
      appBar: AppBar(
        // The background color is part of the blue gradient look
        backgroundColor: Colors.blue,
        elevation: 0, // No shadow
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            // Navigator.pop(context)
          },
        ),
        // Title centered in the blue section
        title: const Text(
          'Your Vehicles',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Padding(
        // Slight padding from the top for the first card
        padding: const EdgeInsets.only(top: 4.0),
        child: ListView.builder(
          itemCount: mockVehicles.length,
          itemBuilder: (context, index) {
            return VehicleCard(vehicle: mockVehicles[index]);
          },
        ),
      ),
    );
  }
}

class VehicleCard extends StatelessWidget {
  final Vehicle vehicle;

  const VehicleCard({required this.vehicle, super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        // Slightly increased padding to give more internal space
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Vehicle Image (Increased size)
            ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: Image.asset(
                vehicle.imageUrl,
                // Increased width and height from 80 to 90
                width: 90,
                height: 90,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey[300],
                  child: const Icon(
                    Icons.directions_car,
                    color: Colors.grey,
                    size: 45,
                  ),
                ),
              ),
            ),
            // Increased space after the image
            const SizedBox(width: 20.0),

            // Vehicle Details (Model, License, Chassis/ID)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Vehicle Model Name (Increased font size)
                  Text(
                    vehicle.model,
                    style: const TextStyle(
                      // Increased font size from 18 to 20
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 10.0), // Increased vertical space
                  // 1. License Plate Row
                  Row(
                    children: [
                      // Increased icon size from 15 to 18
                      const Icon(
                        Icons.local_shipping,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 6), // Increased horizontal space
                      Text(
                        vehicle.licensePlate,
                        // Increased font size from 14 to 16
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(
                    height: 6.0,
                  ), // Increased vertical space between the lines
                  // 2. Chassis/Odometer Row
                  Row(
                    children: [
                      // Increased icon size from 15 to 18
                      const Icon(
                        Icons.headset,
                        size: 18,
                        color: Colors.black54,
                      ),
                      const SizedBox(width: 6), // Increased horizontal space
                      Text(
                        vehicle.chassisNumber,
                        // Increased font size from 14 to 16
                        style: const TextStyle(
                          fontSize: 16,
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
