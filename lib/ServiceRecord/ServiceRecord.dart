import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/ServiceRecord/CustomDateRangePicker.dart';
import 'package:ridefix/ServiceRecord/AddServiceRecord.dart';

class ServiceRecordPage extends StatefulWidget {
  const ServiceRecordPage({super.key});

  @override
  State<ServiceRecordPage> createState() => _ServiceRecordPageState();
}

class _ServiceRecordPageState extends State<ServiceRecordPage> {
  String selectedSort = '';
  List<String> selectedCategories = [];
  DateTimeRange? selectedDateRange;

  final String userId = 'weikit523'; // Hardcoded user ID

  Stream<QuerySnapshot> _getFilteredRecords() {
    Query query = FirebaseFirestore.instance
        .collection('ServiceRecord')
        .where('userId', isEqualTo: userId);

    // Category filter
    if (selectedCategories.isNotEmpty) {
      query = query.where('category', whereIn: selectedCategories);
    }

    // Date range filter
    if (selectedDateRange != null) {
      final startDate = DateFormat(
        'yyyy-MM-dd',
      ).format(selectedDateRange!.start);
      final endDate = DateFormat('yyyy-MM-dd').format(selectedDateRange!.end);
      query = query
          .where('date', isGreaterThanOrEqualTo: startDate)
          .where('date', isLessThanOrEqualTo: endDate);
    }

    // Sorting
    if (selectedSort == 'amount') {
      query = query.orderBy('amount', descending: true);
    } else if (selectedSort == 'date') {
      query = query.orderBy('date', descending: true);
    }

    return query.snapshots();
  }

  Future<void> _selectDateRange() async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) =>
          CustomDateRangePicker(initialDateRange: selectedDateRange),
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
      });
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Maintenance':
        return Icons.settings;
      case 'Toll':
        return Icons.traffic;
      case 'Parking':
        return Icons.local_parking;
      case 'Car Wash':
        return Icons.local_car_wash;
      case 'Insurance':
        return Icons.security;
      case 'Road Tax':
        return Icons.receipt_long;
      case 'Installment':
        return Icons.credit_card;
      case 'Makeup':
        return Icons.brush;
      default:
        return Icons.miscellaneous_services;
    }
  }

  void _resetFilters() {
    setState(() {
      selectedSort = '';
      selectedCategories.clear();
      selectedDateRange = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Records'),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddServiceRecordPage(),
            ),
          );
        },
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Filter Buttons (original layout)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildButton(Icons.sort, 'Sort', _showSortOptions),
                _buildButton(
                  Icons.filter_alt,
                  'Category',
                  _showCategoryOptions,
                ),
                _buildButton(Icons.calendar_month, 'Date', _selectDateRange),
                _buildButton(Icons.refresh, 'Reset', _resetFilters),
              ],
            ),
            const SizedBox(height: 10),

            // Active Filters
            if (selectedSort.isNotEmpty ||
                selectedCategories.isNotEmpty ||
                selectedDateRange != null)
              Center(
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8.0,
                  children: [
                    if (selectedSort.isNotEmpty)
                      Chip(
                        label: Text('Sort: $selectedSort'),
                        backgroundColor: Colors.blue.shade100,
                      ),
                    if (selectedCategories.isNotEmpty)
                      Chip(
                        label: Text(
                          'Category: ${selectedCategories.join(', ')}',
                        ),
                        backgroundColor: Colors.blue.shade100,
                      ),
                    if (selectedDateRange != null)
                      Chip(
                        label: Text(
                          selectedDateRange!.start == selectedDateRange!.end
                              ? 'Date: ${DateFormat('MMM d, yyyy').format(selectedDateRange!.start)}'
                              : 'From: ${DateFormat('MMM d').format(selectedDateRange!.start)} → '
                                    '${DateFormat('MMM d, yyyy').format(selectedDateRange!.end)}',
                        ),
                        backgroundColor: Colors.blue.shade100,
                      ),
                  ],
                ),
              ),

            const SizedBox(height: 10),

            // Service Records List
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _getFilteredRecords(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text('No service records found.'),
                    );
                  }

                  final records = snapshot.data!.docs;

                  return ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record =
                          records[index].data() as Map<String, dynamic>;
                      return Card(
                        elevation: 3,
                        margin: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue.shade100,
                            child: Icon(
                              _getCategoryIcon(record['category'] ?? ''),
                              color: Colors.blue.shade700,
                            ),
                          ),
                          title: Text(record['category'] ?? 'Unknown'),
                          subtitle: Text(
                            'Date: ${record['date'] ?? '-'}\nAmount: RM${record['amount'] ?? '0.00'}',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Compact Button Widget (icon + text in one line)
  Widget _buildButton(IconData icon, String label, VoidCallback onPressed) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4.0),
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue.shade800,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 10),
          ),
          icon: Icon(icon, size: 20),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          onPressed: onPressed,
        ),
      ),
    );
  }

  // Sort Options Dialog
  void _showSortOptions() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Sort Options',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.attach_money),
              title: const Text('Sort by Amount'),
              onTap: () {
                setState(() => selectedSort = 'amount');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Sort by Date'),
              onTap: () {
                setState(() => selectedSort = 'date');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Category Filter Dialog
  void _showCategoryOptions() {
    final categories = [
      'Maintenance',
      'Toll',
      'Parking',
      'Car Wash',
      'Insurance',
      'Road Tax',
      'Installment',
      'Makeup',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Select Categories',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: categories.map((cat) {
                  return CheckboxListTile(
                    title: Row(
                      children: [
                        Icon(
                          _getCategoryIcon(cat),
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 8),
                        Text(cat),
                      ],
                    ),
                    value: selectedCategories.contains(cat),
                    onChanged: (checked) {
                      setModalState(() {
                        if (checked == true) {
                          selectedCategories.add(cat);
                        } else {
                          selectedCategories.remove(cat);
                        }
                      });
                      setState(() {});
                    },
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setModalState(() => selectedCategories.clear());
                  setState(() {});
                },
                child: const Text('Reset', style: TextStyle(color: Colors.red)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Apply',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
