import 'package:flutter/material.dart';

class ServiceRecordDetailsPage extends StatelessWidget {
  final Map<String, dynamic> record;

  const ServiceRecordDetailsPage({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final category = record['category'] ?? 'Unknown';
    final date = record['date'] ?? '-';
    final amount = record['amount']?.toString() ?? '0.00';
    final note = record['note'] ?? '';
    final imgURL = record['imgURL'] ?? '';

    // Dynamic extra fields (auto display all not fixed keys)
    final Map<String, dynamic> extraData = Map.from(record)
      ..removeWhere(
        (key, value) => [
          'id',
          'userId',
          'vehicleId',
          'category',
          'amount',
          'date',
          'note',
          'imgURL',
          'createdAt',
        ].contains(key),
      );

    return Scaffold(
      appBar: AppBar(
        title: Text('$category Details'),
        backgroundColor: Colors.blue.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (imgURL.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  imgURL,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              )
            else
              Container(
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 60,
                    color: Colors.grey,
                  ),
                ),
              ),
            const SizedBox(height: 16),

            // Main info card
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.category, 'Category', category),
                    _buildDetailRow(Icons.calendar_today, 'Date', date),
                    _buildDetailRow(Icons.attach_money, 'Amount', 'RM$amount'),
                    if (note.isNotEmpty)
                      _buildDetailRow(Icons.note, 'Note', note),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Extra data card (if any)
            if (extraData.isNotEmpty)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Additional Details",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...extraData.entries.map(
                        (e) => _buildDetailRow(
                          Icons.info_outline,
                          _formatKey(e.key),
                          e.value.toString(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Helper for consistent key-value row
  Widget _buildDetailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blueAccent, size: 20),
          const SizedBox(width: 8),
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

  /// Formats Firestore keys (e.g. "oilType" → "Oil Type")
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
