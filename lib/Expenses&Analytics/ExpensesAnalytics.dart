import 'package:flutter/material.dart';

// NOTE: In a real Flutter project, you would use a chart library here, e.g.,
// import 'package:fl_chart/fl_chart.dart';

class ExpensesAnalyticsPage extends StatefulWidget {
  const ExpensesAnalyticsPage({super.key});

  @override
  State<ExpensesAnalyticsPage> createState() => _ExpensesAnalyticsPageState();
}

class _ExpensesAnalyticsPageState extends State<ExpensesAnalyticsPage> {
  // State variables for the UI controls
  String _selectedDuration = 'YEARS'; // DAYS, MONTHS, YEARS
  String _currentPeriod = 'JAN - DEC 2025';
  bool _isBarChart =
      true; // True for Bar Chart (Left side of the image), False for Pie Chart (Right side)

  // Mock Data (matches the image)
  final double monthlyAverage = 1505.00;
  final double totalExpenses = 3010.10;
  final double tco =
      3010.10; // Total Cost of Ownership often matches Total Expenses initially

  final List<Map<String, dynamic>> topCategories = const [
    {
      'category': 'Insurance',
      'entries': 1,
      'amount': 2300.00,
      'icon': Icons.car_crash,
    },
    {
      'category': 'Maintenance',
      'entries': 2,
      'amount': 670.00,
      'icon': Icons.settings,
    },
    {'category': 'Makeup', 'entries': 1, 'amount': 270.00, 'icon': Icons.brush},
    {
      'category': 'Car Wash',
      'entries': 1,
      'amount': 15.00,
      'icon': Icons.local_car_wash,
    },
    {'category': 'Tol', 'entries': 1, 'amount': 10.50, 'icon': Icons.traffic},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Expenses Reports',
          style: TextStyle(color: Colors.white),
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF2196F3), // Vibrant blue
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildFilterTabs(),
            _buildPeriodNavigation(),
            _buildMonthlyAverage(),
            _buildChartArea(context),
            _buildSummaryTable(),
            _buildTopCategories(),
          ],
        ),
      ),
    );
  }

  // --- UI Components ---

  Widget _buildFilterTabs() {
    // Style for the duration tabs (DAYS, MONTHS, YEARS)
    Widget buildDurationTab(String label) {
      final isSelected = _selectedDuration == label;
      return GestureDetector(
        onTap: () => setState(() => _selectedDuration = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected ? Border.all(color: Colors.blue.shade100) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.blue.shade700 : Colors.black54,
            ),
          ),
        ),
      );
    }

    // Style for the chart/category icon buttons
    Widget buildIconButton({
      required IconData icon,
      required bool isBarChartButton,
    }) {
      final isSelected = isBarChartButton ? _isBarChart : !_isBarChart;
      return GestureDetector(
        onTap: () => setState(() => _isBarChart = isBarChartButton),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade700 : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.2),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected ? Colors.white : Colors.black54,
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      // --- START: MODIFIED LAYOUT ---
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. LEFT: Bar Chart / Pie Chart Toggles
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildIconButton(icon: Icons.bar_chart, isBarChartButton: true),
              const SizedBox(width: 8),
              buildIconButton(icon: Icons.pie_chart, isBarChartButton: false),
            ],
          ),

          // 2. MIDDLE: Date Range Filters (DAYS, MONTHS, YEARS)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              buildDurationTab('DAYS'),
              const SizedBox(width: 8),
              buildDurationTab('MONTHS'),
              const SizedBox(width: 8),
              buildDurationTab('YEARS'),
            ],
          ),

          // 3. RIGHT: Category Filter Icon
          const Icon(Icons.filter_alt, color: Colors.black54),
        ],
      ),
      // --- END: MODIFIED LAYOUT ---
    );
  }

  Widget _buildPeriodNavigation() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 16,
              color: Colors.black54,
            ),
            onPressed: () {
              // TODO: Implement logic to move to the previous period
            },
          ),
          Text(
            _currentPeriod,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          IconButton(
            icon: const Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.black54,
            ),
            onPressed: () {
              // TODO: Implement logic to move to the next period
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyAverage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monthly Average',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          ),
          Text(
            'RM ${monthlyAverage.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartArea(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Placeholder for the actual chart widget
          Container(
            height: 200,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _isBarChart
                ? const Text(
                    'Bar Chart Placeholder (JAN - DEC)',
                    style: TextStyle(color: Colors.black54),
                  )
                : const Text(
                    'Pie Chart Placeholder (Category Breakdown)',
                    style: TextStyle(color: Colors.black54),
                  ),
          ),
          // Additional labels matching the bar chart image
          if (_isBarChart)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildChartLegend(color: Colors.red, label: 'Highest Month'),
                  _buildChartLegend(
                    color: Colors.orange,
                    label: 'Recent Month',
                  ),
                  _buildChartLegend(color: Colors.blue, label: 'Average'),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChartLegend({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black87),
        ),
      ],
    );
  }

  Widget _buildSummaryTable() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildSummaryRow(
            Icons.monetization_on,
            'Total Expenses',
            totalExpenses,
          ),
          const Divider(height: 1, color: Colors.grey),
          _buildSummaryRow(Icons.calculate, 'TCO', tco),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.black87, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 16, color: Colors.black87),
              ),
            ],
          ),
          Text(
            'RM ${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCategories() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP CATEGORIES',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: topCategories
                  .map((category) => _buildCategoryTile(category))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> category) {
    return ListTile(
      leading: Icon(category['icon'] as IconData, color: Colors.black),
      title: Text(
        category['category'],
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${category['entries']} entries',
        style: const TextStyle(fontSize: 12),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'RM ${category['amount'].toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black54),
        ],
      ),
      onTap: () {
        // TODO: Navigate to a detailed view for this category
      },
    );
  }
}
