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
          // --- 1. Vehicle Image (FULL WIDTH, SAME SIZE) ---
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: AspectRatio(
              aspectRatio: 16 / 9, // Maintain consistent rectangle ratio
              child: Image.network(
                details.imageUrl,
                fit: BoxFit.contain, // ✅ show whole image, auto adjust size
                width: double.infinity,
                height: 220, // adjust height as you wish
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

          // --- 2. Edit & Delete Buttons Row ---
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.grey, size: 24),
                onPressed: () {
                  // TODO: Handle Edit
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.grey, size: 24),
                onPressed: () {
                  // TODO: Handle Delete
                },
              ),
            ],
          ),

          const SizedBox(height: 8.0),

          // --- 3. Details Card ---
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
                Text(
                  details.model,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 12.0),

                DetailRow(
                  label: 'Vehicle Plate Number',
                  value: details.plateNumber,
                ),
                DetailRow(label: 'Color', value: details.color),
                DetailRow(
                  label: 'Manufacture Year',
                  value: details.year.toString(),
                ),
                DetailRow(label: 'Mileage', value: '${details.mileage} km'),
                DetailRow(
                  label: 'Road Tax Expiry',
                  value: details.roadTaxExpiry,
                ),

                const Divider(height: 24, thickness: 1, color: Colors.grey),

                DetailRow(
                  label: 'Service Histories',
                  value: details.serviceHistoryCount.toString(),
                ),
                DetailRow(
                  label: 'Fuel Entries',
                  value: details.fuelEntriesCount.toString(),
                ),
                DetailRow(
                  label: 'Total Expenses',
                  value: 'RM ${details.totalExpenses.toStringAsFixed(2)}',
                  valueColor: Colors.red,
                ),
                DetailRow(
                  label: 'Avg. Monthly Expenses',
                  value: 'RM ${details.avgMonthlyExpenses.toStringAsFixed(2)}',
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
          Text(
            '$label:',
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
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
