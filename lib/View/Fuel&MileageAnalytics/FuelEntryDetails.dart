import 'package:flutter/material.dart';
import 'package:ridefix/View/ServiceRecord/FullScreenImage.dart';

class FuelEntryDetailsPage extends StatelessWidget {
  final Map<String, dynamic> record;

  const FuelEntryDetailsPage({super.key, required this.record});

  // Helper Widget to build the image display logic
  Widget _buildImageDisplay(BuildContext context, String imageUrl) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FullScreenImagePage(imageUrl: imageUrl),
          ),
        );
      },
      child: Hero(
        tag: imageUrl,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: double.infinity,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Container(
                height: 220,
                color: Colors.grey[200],
                child: Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Fallback to a clickable error message
              return Container(
                height: 50,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: const Center(
                  child: Text(
                    "Error loading image. Tap to view URL.",
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 🎨 Choose icon for field
  IconData _getIconForField(String key) {
    switch (key) {
      case 'date':
        return Icons.calendar_today;
      case 'amount':
        return Icons.money;
      case 'mileage':
        return Icons.speed;
      case 'fuelType':
        return Icons.local_gas_station;
      case 'pricePerLiter':
        return Icons.local_offer;
      case 'volume':
        return Icons.opacity;
      case 'note':
        return Icons.note;
      case 'plateNumber':
        return Icons.credit_card;
      case 'station':
        return Icons.storefront;
      case 'fuelEfficiency':
        return Icons.trending_up;
      case 'isFullTank':
        return Icons.check_circle_outline;
      default:
        return Icons.info_outline;
    }
  }

  /// 📋 Row builder for label + value
  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.black, fontSize: 16),
                children: [
                  TextSpan(
                    text: "$title: ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🔤 Format Firestore keys to readable labels
  String _formatKey(String key) {
    final buffer = StringBuffer();
    for (int i = 0; i < key.length; i++) {
      if (i == 0) {
        buffer.write(key[i].toUpperCase());
      } else if (key[i].toUpperCase() == key[i] && key[i] != '_') {
        buffer.write(' ${key[i]}');
      } else if (key[i] == '_') {
        buffer.write(' ');
      } else {
        buffer.write(key[i]);
      }
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    // 1. Extract and format essential data
    final date = record['date'] ?? '-';
    // Ensure amount is handled correctly if it comes as a string or null
    final amount = (record['amount'] is num)
        ? (record['amount'] as num).toStringAsFixed(2)
        : '0.00';
    final mileage = record['mileage'] ?? 'N/A';
    final plateNumber = record['plateNumber'] ?? 'N/A';
    final note = record['note'] ?? '';
    final fuelType = record['fuelType'] ?? 'N/A';
    final pricePerLiter = (record['pricePerLiter'] is num)
        ? (record['pricePerLiter'] as num).toStringAsFixed(3)
        : '0.000';
    final volume = (record['volume'] is num)
        ? (record['volume'] as num).toStringAsFixed(3)
        : '0.000';
    final station = record['station'] ?? 'N/A';
    // 💡 Minor correction: Check if isFullTank is present AND true
    final isFullTankValue =
        (record['isFullTank'] == true || record['isFullTank'] == 'true')
        ? 'Yes'
        : 'No';

    // Check if fuelEfficiency is a positive number
    final isFuelEfficiencyValid =
        record['fuelEfficiency'] is num &&
        (record['fuelEfficiency'] as num) > 0;

    final fuelEfficiency = isFuelEfficiencyValid
        ? (record['fuelEfficiency'] as num).toStringAsFixed(2)
        : 'N/A';

    final fuelEfficiencyUnit = isFuelEfficiencyValid ? ' KM/L' : '';

    final imgURL =
        (record['imageUrl'] is String &&
            (record['imageUrl'] as String).isNotEmpty)
        ? record['imageUrl']
        : null;

    // 2. Define display labels for known keys
    final Map<String, String> displayLabels = {
      'plateNumber': 'Vehicle Plate',
      'station': 'Petrol Station',
      'date': 'Fill-up Date',
      'mileage': 'Odometer Reading (KM)',
      'fuelEfficiency': 'Fuel Efficiency',
      'fuelType': 'Fuel Type',
      'volume': 'Volume (Liters)',
      'pricePerLiter': 'Price/Liter (RM)',
      'amount': 'Total Cost (RM)',
      'note': 'Note',
      'isFullTank': 'Full Tank',
    };

    // 3. Construct display data in a logical order
    final Map<String, dynamic> displayData =
        {
            'plateNumber': plateNumber,
            'station': station,
            'date': date,
            'mileage': mileage,
            'fuelEfficiency': fuelEfficiency,
            'fuelType': fuelType,
            'volume': volume,
            'pricePerLiter': pricePerLiter,
            'amount': amount,
            'isFullTank': isFullTankValue, // Use the corrected value
            'note': note,
          }
          // The filtering logic you added previously is kept here
          ..removeWhere((key, value) {
            // 1. Identify fields that must *always* be shown, even if 'N/A' or '0.000'
            const essentialKeys = {
              'plateNumber',
              'mileage',
              'fuelEfficiency',
              'isFullTank',
              'amount',
              'pricePerLiter',
              'volume',
              'date',
              'fuelType',
            };

            if (essentialKeys.contains(key)) {
              return false; // Never remove essential fields
            }

            // 2. For non-essential fields (like 'station' or 'note'), remove if empty/default.
            return value == 'N/A' ||
                value == null ||
                value.toString().trim().isEmpty;
          });

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fuel Entry Details',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ⛽ Details list
                ...displayData.entries.map((entry) {
                  final label =
                      displayLabels[entry.key] ?? _formatKey(entry.key);
                  String value;
                  String key = entry.key;

                  // Handle special formatting for known fuel fields
                  switch (key) {
                    case 'amount':
                      value = 'RM${amount}';
                      break;
                    case 'pricePerLiter':
                      value = 'RM${pricePerLiter}';
                      break;
                    case 'volume':
                      value = '${volume} L';
                      break;
                    case 'mileage':
                      value = '${mileage} KM';
                      break;
                    case 'fuelEfficiency':
                      // Use the fixed fuelEfficiency and its correct unit
                      value = '${fuelEfficiency}${fuelEfficiencyUnit}';
                      break;
                    default:
                      value = entry.value.toString();
                      break;
                  }

                  return _buildDetailRow(_getIconForField(key), label, value);
                }),

                // 🖼️ Display image (if available)
                if (imgURL != null) ...[
                  const SizedBox(height: 16),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "Receipt Image",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey,
                      ),
                    ),
                  ),
                  _buildImageDisplay(context, imgURL),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
