import 'package:flutter/material.dart';

// --- Data Model for Vehicle Details ---
class VehicleDetails {
  final String plateNumber;
  final String model;
  final String color;
  final int year;
  final int mileage;
  final String roadTaxExpiry;
  final int serviceHistoryCount;
  final int fuelEntriesCount;
  final double totalExpenses;
  final double avgMonthlyExpenses;
  final String imageUrl;

  VehicleDetails({
    required this.plateNumber,
    required this.model,
    required this.color,
    required this.year,
    required this.mileage,
    required this.roadTaxExpiry,
    required this.serviceHistoryCount,
    required this.fuelEntriesCount,
    required this.totalExpenses,
    required this.avgMonthlyExpenses,
    required this.imageUrl,
  });
}

// --- Sample Data (To run the screen) ---
final VehicleDetails mockDetails = VehicleDetails(
  plateNumber: 'XXX 1234',
  model: 'Honda Civic',
  color: 'White',
  year: 2017,
  mileage: 2409190,
  roadTaxExpiry: '08/03/26',
  serviceHistoryCount: 10,
  fuelEntriesCount: 20,
  totalExpenses: 3010.00,
  avgMonthlyExpenses: 1505.00,
  imageUrl:
      'assets/honda_civic_detail.jpg', // **Ensure this asset path is correct**
);

// ------------------------------------------------------------------
// --- Vehicle Details Page Widget ---
// ------------------------------------------------------------------
class VehicleDetailsPage extends StatelessWidget {
  final VehicleDetails details;

  const VehicleDetailsPage({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      // Blue AppBar
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          details.plateNumber,
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
          // --- 1. Vehicle Image ---
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
              details.imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: 200,
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                height: 200,
                color: Colors.grey[300],
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.grey,
                  size: 60,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10.0),

          // --- 2. Action Buttons Row (Icons outside the image) ---
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Edit Button
              IconButton(
                icon: Icon(
                  Icons.edit,
                  color: Colors.grey[600], // Visible on grey background
                  size: 24,
                ),
                onPressed: () {
                  /* Handle Edit */
                },
              ),
              // Delete Button
              IconButton(
                icon: Icon(
                  Icons.delete,
                  color: Colors.grey[600], // Visible on grey background
                  size: 24,
                ),
                onPressed: () {
                  /* Handle Delete */
                },
              ),
            ],
          ),

          const SizedBox(height: 10.0), // Space before the detail card
          // --- 3. Details Card/Container ---
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vehicle Model Title
                Text(
                  details.model,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12.0),

                // Details List
                DetailRow(
                  label: 'Vehicle Plate Number',
                  value: details.plateNumber,
                ),
                DetailRow(label: 'Color', value: details.color),
                DetailRow(
                  label: 'Manufacture Year',
                  value: details.year.toString(),
                ),
                DetailRow(label: 'Mileage', value: details.mileage.toString()),
                DetailRow(
                  label: 'Road Tax Expired',
                  value: details.roadTaxExpiry,
                ),

                // Separator for the statistics section
                const Divider(height: 24, thickness: 1, color: Colors.grey),

                DetailRow(
                  label: 'Services Histories',
                  value: details.serviceHistoryCount.toString(),
                ),
                DetailRow(
                  label: 'Fuel Entries',
                  value: details.fuelEntriesCount.toString(),
                ),

                // Format currency
                DetailRow(
                  label: 'Total Expenses',
                  value: '${details.totalExpenses.toStringAsFixed(2)}',
                  valueColor: Colors.red,
                ),
                DetailRow(
                  label: 'Avg. Monthly Expenses',
                  value: '${details.avgMonthlyExpenses.toStringAsFixed(2)}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- Helper Widget for Key/Value Rows ---
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
          // Left side (Label)
          Text(
            '$label :',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
          // Right side (Value)
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
