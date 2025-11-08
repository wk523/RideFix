import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/ExpensesAnalytics/ExpensesAnalyticsDatabase';

class ExpensesAnalyticsPage extends StatefulWidget {
  const ExpensesAnalyticsPage({super.key});

  @override
  State<ExpensesAnalyticsPage> createState() => _ExpensesAnalyticsPageState();
}

class _ExpensesAnalyticsPageState extends State<ExpensesAnalyticsPage> {
  final _db = ExpensesAnalyticsDatabase();
  String _selectedDuration = 'YEARS'; // DAYS | MONTHS | YEARS
  String _currentPeriod = DateFormat('yyyy').format(DateTime.now());
  bool _isBarChart = true;
  bool showAll = false; // 👈 for controlling “Show All” toggle

  double monthlyAverage = 0.0;
  Map<String, double> _monthlyData =
      {}; // e.g. {'Jan': 1200.0, 'Feb': 900.0, ...}
  Map<String, double> _categoryData =
      {}; // e.g. {'Maintenance': 670.0, 'Insurance': 2300.0}
  double _totalExpenses = 0.0;
  double tco = 0.0;
  List<MapEntry<String, double>> monthlyEntries = [];
  List<Map<String, dynamic>> topCategories = [];
  bool _loading = true;
  final String userId = 'weikit523'; // change as needed

  @override
  void initState() {
    super.initState();
    _loadAnalyticsData();
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _loading = true);

    final summary = await _db.fetchExpenseSummary(userId: userId);
    final categoryMap = await _db.fetchExpensesByCategory(userId: userId);

    // ✅ Use monthlyTotals directly (already in yyyy-MM format)
    final monthlyTotals = Map<String, double>.from(
      summary['monthlyTotals'] ?? {},
    );

    // ✅ Sort keys chronologically
    final sortedKeys = monthlyTotals.keys.toList()
      ..sort(
        (a, b) => DateTime.parse('$a-01').compareTo(DateTime.parse('$b-01')),
      );

    monthlyEntries = sortedKeys
        .map((k) => MapEntry(k, monthlyTotals[k]!))
        .toList();

    // ✅ Sort category data
    topCategories =
        categoryMap.entries
            .map((e) => {'category': e.key, 'amount': e.value})
            .toList()
          ..sort(
            (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
          );

    setState(() {
      _monthlyData = monthlyTotals;
      _categoryData = categoryMap;
      _totalExpenses = summary['total'] ?? 0.0;
      monthlyAverage = summary['monthlyAverage'] ?? 0.0;
      tco = summary['tco'] ?? 0.0;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Expenses Analytics'),
        backgroundColor: const Color(0xFF2196F3),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    _buildFilterTabs(),
                    _buildPeriodNavigation(),
                    _buildMonthlyAverage(),
                    _buildChartArea(context),
                    _buildSummaryRow(
                      Icons.monetization_on,
                      'Total Expenses',
                      _totalExpenses,
                    ),
                    _buildTopCategories(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterTabs() {
    Widget buildDurationTab(String label) {
      final isSelected = _selectedDuration == label;
      return GestureDetector(
        onTap: () => setState(() => _selectedDuration = label),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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

    Widget buildIconButton({required IconData icon, required bool isBar}) {
      final isSelected = (isBar && _isBarChart) || (!isBar && !_isBarChart);
      return GestureDetector(
        onTap: () => setState(() => _isBarChart = isBar),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue.shade700 : Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.grey.withOpacity(0.15), blurRadius: 3),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              buildIconButton(icon: Icons.bar_chart, isBar: true),
              const SizedBox(width: 8),
              buildIconButton(icon: Icons.pie_chart, isBar: false),
            ],
          ),
          Row(
            children: [
              buildDurationTab('DAYS'),
              const SizedBox(width: 8),
              buildDurationTab('MONTHS'),
              const SizedBox(width: 8),
              buildDurationTab('YEARS'),
            ],
          ),
          const Icon(Icons.filter_alt, color: Colors.black54),
        ],
      ),
    );
  }

  Widget _buildPeriodNavigation() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 16),
            onPressed: () {},
          ),
          Text(
            _currentPeriod,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.arrow_forward_ios, size: 16),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyAverage() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Monthly Average',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
              Text(
                'RM ${monthlyAverage.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildChartArea(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 6),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 265,
            child: _isBarChart
                ? _buildBarChart(monthlyEntries)
                : _buildPieChart(_categoryData),
          ),
        ],
      ),
    );
  }

  // -----------------------------
  // 1) Bar chart builder
  // -----------------------------
  Widget _buildBarChart(List<MapEntry<String, double>> monthlyEntries) {
    if (monthlyEntries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text("No data to display."),
        ),
      );
    }

    final maxY =
        (monthlyEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b) *
                1.2)
            .ceilToDouble();

    return LayoutBuilder(
      builder: (context, constraints) {
        final chartHeight = constraints.maxWidth * 0.6; // auto scale

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Monthly Expenses Overview',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            SizedBox(
              height: chartHeight.clamp(200, 350), // keep within nice range
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(show: true, drawVerticalLine: false),

                  titlesData: FlTitlesData(
                    show: true,

                    // Left Axis (RM values)
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: maxY / 5,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'RM${value.toInt()}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Bottom Axis (Months)
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= monthlyEntries.length) {
                            return const SizedBox.shrink();
                          }
                          final label = monthlyEntries[value.toInt()].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),

                  barGroups: monthlyEntries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final amount = entry.value.value;

                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: amount,
                          width: 22,
                          color: Colors.blueAccent,
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Colors.black12,
                            width: 0.5,
                          ),
                        ),
                      ],
                      showingTooltipIndicators: [0],
                    );
                  }).toList(),

                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final month = monthlyEntries[group.x.toInt()].key;
                        final amount = monthlyEntries[group.x.toInt()].value;
                        final total = monthlyEntries.fold<double>(
                          0.0,
                          (sum, e) => sum + e.value,
                        );
                        final percent = total > 0 ? (amount / total) * 100 : 0;
                        return BarTooltipItem(
                          '$month\nRM${amount.toStringAsFixed(2)} (${percent.toStringAsFixed(1)}%)',
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // -----------------------------
  // 2) Pie chart builder + legend
  // -----------------------------
  Widget _buildPieChart(Map<String, double> data) {
    final total = data.values.fold(0.0, (sum, v) => sum + v);

    // Limit to top 6 categories for compact display
    final limitedData = showAll
        ? data
        : Map<String, double>.fromEntries(data.entries.take(6));

    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.brown,
    ];

    final sections = limitedData.entries.map((entry) {
      final percent = total > 0 ? (entry.value / total) * 100 : 0;
      final color =
          colors[limitedData.keys.toList().indexOf(entry.key) % colors.length];

      return PieChartSectionData(
        color: color,
        value: entry.value,
        radius: 75,
        title:
            'RM ${entry.value.toStringAsFixed(0)} (${percent.toStringAsFixed(1)}%)',
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.black,
        ),
        titlePositionPercentageOffset: 0.6,
      );
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          'Expenses Breakdown',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 20),

        // ✅ Center chart + legend horizontally
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 🔸 Pie Chart
              SizedBox(
                height: 200,
                width: 200,
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 25,
                    sectionsSpace: 2,
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),

              const SizedBox(width: 32),

              // 🔸 Legend Labels (Only category names)
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: limitedData.entries.map((entry) {
                  final color =
                      colors[limitedData.keys.toList().indexOf(entry.key) %
                          colors.length];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),

        if (data.length > 6) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() => showAll = !showAll),
              child: Text(
                showAll ? 'Show Less' : 'Show All',
                style: const TextStyle(color: Colors.blue),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, double amount) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14)),
              ],
            ),
            Text(
              'RM ${amount.toStringAsFixed(2)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );

  Widget _buildTopCategories() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TOP CATEGORIES',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 6),
              ],
            ),
            child: Column(
              children: topCategories.map((c) {
                return ListTile(
                  title: Text(c['category']),
                  trailing: Text(
                    'RM ${(c['amount'] as double).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
