import 'package:flutter/material.dart';
import 'package:ridefix/View/ServiceRecord/FullScreenImage.dart';

class ServiceRecordDetailsPage extends StatelessWidget {
  final Map<String, dynamic> record;

  const ServiceRecordDetailsPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final category = record['category'] ?? 'Unknown';
    final date = record['date'] ?? '-';
    final amount = (record['amount'] is num)
        ? (record['amount'] as num).toStringAsFixed(2)
        : '0.00';
    final note = record['note'] ?? '';
    final imgURL =
        (record['imgURL'] is String && (record['imgURL'] as String).isNotEmpty)
        ? record['imgURL']
        : null;
    final plateNumber = record['plateNumber'] ?? 'N/A';

    // ✅ Merge and clean record data
    final Map<String, dynamic> displayData = Map.from(record)
      ..removeWhere(
        (key, value) =>
            [
              'id',
              'userId',
              'vehicleId',
              'imgURL',
              'createdAt',
            ].contains(key) ||
            (value == null || value.toString().trim().isEmpty),
      );

    // ✅ Display labels for known keys
    final Map<String, String> displayLabels = {
      'category': 'Category',
      'date': 'Date',
      'amount': 'Amount (RM)',
      'note': 'Note',
      'plateNumber': 'Vehicle Plate',
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '$category Details',
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
                // 🧾 Details list
                ...displayData.entries.map((entry) {
                  final label =
                      displayLabels[entry.key] ?? _formatKey(entry.key);
                  final value = entry.key == 'amount'
                      ? 'RM${amount.toString()}'
                      : entry.value.toString();

                  return _buildDetailRow(
                    _getIconForField(entry.key),
                    label,
                    value,
                  );
                }),

                const SizedBox(height: 16),

                // 🖼️ Display image (if available)
                // 🖼️ Display image (if available)
                if (imgURL != null)
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => FullScreenImagePage(imageUrl: imgURL),
                        ),
                      );
                    },
                    child: Hero(
                      tag: imgURL,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          imgURL,
                          width: double.infinity,
                          fit: BoxFit
                              .contain, // ✅ auto adjust — keep natural ratio
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return Container(
                              height: 220,
                              color: Colors.grey[200],
                              child: Center(
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 220,
                              color: Colors.grey[200],
                              child: const Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 48,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 🎨 Choose icon for field
  IconData _getIconForField(String key) {
    switch (key) {
      case 'category':
        return Icons.category;
      case 'date':
        return Icons.calendar_today;
      case 'amount':
        return Icons.attach_money;
      case 'note':
        return Icons.note;
      case 'plateNumber':
        return Icons.directions_car;
      default:
        return Icons.info_outline;
    }
  }

  /// 📋 Row builder for label + value
  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
}
