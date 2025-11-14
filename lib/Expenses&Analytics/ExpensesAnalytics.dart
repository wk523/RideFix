import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/ExpensesAnalytics/ExpensesAnalyticsDatabase.dart';
import 'package:ridefix/ServiceRecord/AddServiceRecord.dart';

class ExpensesAnalyticsPage extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const ExpensesAnalyticsPage({super.key, required this.userDoc});

  @override
  State<ExpensesAnalyticsPage> createState() => _ExpensesAnalyticsPageState();
}

class _ExpensesAnalyticsPageState extends State<ExpensesAnalyticsPage> {
  final _db = ExpensesAnalyticsDatabase();
  String _selectedDuration = 'MONTHS';
  String _currentPeriod = DateFormat('yyyy').format(DateTime.now());
  DateTime _currentDate = DateTime.now();

  bool _isBarChart = true;
  bool showAll = false;
  bool _loading = true;

  Offset _dragStart = Offset.zero;
  int? _touchedGroupIndex;

  double monthlyAverage = 0.0;
  double _totalExpenses = 0.0;
  double tco = 0.0;

  Map<String, double> _monthlyData = {};
  Map<String, double> _categoryData = {};
  List<MapEntry<String, double>> monthlyEntries = [];
  List<Map<String, dynamic>> topCategories = [];

  final String userId = 'weikit523'; // Will Change to Authenticated User ID

  @override
  void initState() {
    super.initState();
    _updateCurrentPeriod();
    _loadAnalyticsData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Expenses Analytics',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              _buildFilterTabs(),
              _buildPeriodNavigation(),
              _buildChartArea(context),
              _buildTopCategories(),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------------
  // 🔹 Load Data Based on Current Date and Duration
  // ----------------------------------------------------------------
  Future<void> _loadAnalyticsData() async {
    setState(() => _loading = true);

    final summary = await _db.fetchExpenseSummary(
      userId: userId,
      duration: _selectedDuration,
      referenceDate: _currentDate,
    );

    final categoryMap = await _db.fetchExpensesByCategory(
      userId: userId,
      duration: _selectedDuration,
      referenceDate: _currentDate,
    );

    final groupedTotals = Map<String, double>.from(
      summary['groupedTotals'] ?? {},
    );
    final sortedKeys = groupedTotals.keys.toList()..sort();
    monthlyEntries = sortedKeys
        .map((k) => MapEntry(k, groupedTotals[k]!))
        .toList();

    final sortedCategories = categoryMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final tcoResult = await _db.predictTCO(userId: userId);
    final predictedNextTCO = tcoResult['predictedTotal'] ?? 0.0;

    if (mounted) {
      setState(() {
        _monthlyData = groupedTotals;
        _categoryData = categoryMap;
        _totalExpenses = summary['total'] ?? 0.0;
        monthlyAverage = summary['average'] ?? 0.0;
        tco = predictedNextTCO;
        _loading = false;
        topCategories = sortedCategories
            .take(5)
            .map((e) => {'category': e.key, 'amount': e.value})
            .toList();
      });
    }
  }

  // ----------------------------------------------------------------
  // 🔹 Update Current Period Text
  // ----------------------------------------------------------------
  void _updateCurrentPeriod() {
    if (_selectedDuration == 'YEARS') {
      _currentPeriod = '${_currentDate.year}';
    } else if (_selectedDuration == 'MONTHS') {
      _currentPeriod = DateFormat('MMM yyyy').format(_currentDate);
    } else {
      final startOfWeek = _currentDate.subtract(
        Duration(days: _currentDate.weekday - 1),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      _currentPeriod =
          '${DateFormat('d MMM').format(startOfWeek)} - ${DateFormat('d MMM').format(endOfWeek)}';
    }
  }

  // ----------------------------------------------------------------
  // 🔹 Navigation Between Periods
  // ----------------------------------------------------------------
  void _handlePreviousPeriod() {
    setState(() {
      if (_selectedDuration == 'YEARS') {
        _currentDate = DateTime(_currentDate.year - 1);
      } else if (_selectedDuration == 'MONTHS') {
        _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
      } else {
        _currentDate = _currentDate.subtract(const Duration(days: 7));
      }
      _updateCurrentPeriod();
    });
    _loadAnalyticsData();
  }

  void _handleNextPeriod() {
    final now = DateTime.now();
    setState(() {
      if (_selectedDuration == 'YEARS') {
        if (_currentDate.year < now.year) {
          _currentDate = DateTime(_currentDate.year + 1);
        } else {
          return;
        }
      } else if (_selectedDuration == 'MONTHS') {
        if (_currentDate.year < now.year ||
            (_currentDate.year == now.year && _currentDate.month < now.month)) {
          _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
        } else {
          return;
        }
      } else {
        final nextWeek = _currentDate.add(const Duration(days: 7));
        if (nextWeek.isBefore(now)) {
          _currentDate = nextWeek;
        } else {
          return;
        }
      }
      _updateCurrentPeriod();
    });
    _loadAnalyticsData();
  }

  // ----------------------------------------------------------------
  // 🔹 Filter Bar (centered filters + right icon restored)
  // ----------------------------------------------------------------
  Widget _buildFilterTabs() {
    Widget buildDurationTab(String label) {
      final isSelected = _selectedDuration == label;
      return GestureDetector(
        onTap: () async {
          if (_selectedDuration == label) return;

          setState(() {
            _selectedDuration = label;
            _currentDate = DateTime.now(); // reset to current period
            _updateCurrentPeriod();
          });

          await _loadAnalyticsData();
        },
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

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Chart toggle
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _isBarChart = true),
                icon: Icon(
                  Icons.bar_chart,
                  color: _isBarChart ? Colors.blue : Colors.black54,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _isBarChart = false),
                icon: Icon(
                  Icons.pie_chart,
                  color: !_isBarChart ? Colors.blue : Colors.black54,
                ),
              ),
            ],
          ),
          // Centered period filters
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildDurationTab('DAYS'),
              const SizedBox(width: 8),
              buildDurationTab('MONTHS'),
              const SizedBox(width: 8),
              buildDurationTab('YEARS'),
            ],
          ),
          // Right side icon restored
          IconButton(
            icon: const Icon(Icons.filter_list, color: Colors.black54),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 🔹 Period Navigation Row
  // ----------------------------------------------------------------
  Widget _buildPeriodNavigation() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _handlePreviousPeriod,
          icon: const Icon(Icons.arrow_back_ios, size: 16),
        ),
        Text(
          _currentPeriod,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        IconButton(
          onPressed: _handleNextPeriod,
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ],
    ),
  );

  Widget _buildChartArea(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 📊 Title
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _selectedDuration == 'DAYS'
                  ? 'Weekly Expenses Overview'
                  : _selectedDuration == 'MONTHS'
                  ? 'Monthly Expenses Overview'
                  : 'Yearly Expenses Overview',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // 💰 Average section
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDuration == 'DAYS'
                      ? 'Daily Average'
                      : _selectedDuration == 'MONTHS'
                      ? 'Weekly Average'
                      : 'Monthly Average',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  'RM ${monthlyAverage.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // 📈 Chart Section with swipe gesture
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (details) {
              _dragStart = details.globalPosition;
            },
            onHorizontalDragUpdate: (details) {
              final dx = details.globalPosition.dx - _dragStart.dx;
              if (dx.abs() > 50) {
                // 👈 sensitivity threshold
                if (dx > 0 && !_isBarChart) {
                  // Swipe right → from Pie → Bar Chart
                  setState(() => _isBarChart = true);
                } else if (dx < 0 && _isBarChart) {
                  // Swipe left → from Bar → Pie Chart
                  setState(() => _isBarChart = false);
                }
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        final isBar = child.key == const ValueKey(true);

                        // 👇 Slide direction based on target chart
                        final beginOffset = isBar
                            ? const Offset(-0.5, 0) // Bar slides in from left
                            : const Offset(0.5, 0); // Pie slides in from right

                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: beginOffset,
                            end: Offset.zero,
                          ).animate(animation),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },

                  child: _loading
                      ? const SizedBox.shrink()
                      : _monthlyData.isEmpty
                      ? _buildNoDataWidget(context)
                      : SizedBox(
                          key: ValueKey(_isBarChart),
                          height: 265,
                          child: _isBarChart
                              ? _buildBarChart(monthlyEntries)
                              : _buildPieChart(_categoryData),
                        ),
                ),
                if (_loading)
                  Container(
                    color: Colors.white.withOpacity(0.6),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 💵 Total & TCO Summary inside the same box
          Divider(color: Colors.grey.withOpacity(0.3)),

          _buildSummaryRow(
            Icons.monetization_on,
            'Total Expenses',
            _totalExpenses,
          ),
          if (_selectedDuration == 'YEARS')
            _buildSummaryRow(
              Icons.trending_up,
              'Predicted Next Year Cost (TCO)',
              tco,
            ),

          const SizedBox(height: 6),
          Center(
            child: Text(
              '← Swipe to switch chart →',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------
  // 🔹 No Data Widget with Conditional Navigation
  // ----------------------------------------------------------------
  Widget _buildNoDataWidget(BuildContext context) {
    String periodText;

    if (_selectedDuration == 'DAYS') {
      periodText = 'this week';
    } else if (_selectedDuration == 'MONTHS') {
      periodText = 'this month';
    } else {
      periodText = 'this year';
    }

    final now = DateTime.now();

    bool isCurrentPeriod = false;

    if (_selectedDuration == 'YEARS') {
      isCurrentPeriod = _currentDate.year == now.year;
    }

    if (_selectedDuration == 'MONTHS') {
      isCurrentPeriod =
          _currentDate.year == now.year && _currentDate.month == now.month;
    }

    if (_selectedDuration == 'DAYS') {
      final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfThisWeek = startOfThisWeek.add(const Duration(days: 6));

      isCurrentPeriod =
          _currentDate.isAfter(
            startOfThisWeek.subtract(const Duration(seconds: 1)),
          ) &&
          _currentDate.isBefore(endOfThisWeek.add(const Duration(seconds: 1)));
    }

    return SizedBox.expand(
      child: Center(
        // <-- Centers your no-data message in available space
        child: Column(
          key: const ValueKey('noData'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'No service record $periodText.',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),

            TextButton(
              onPressed: isCurrentPeriod
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AddServiceRecordPage(userDoc: widget.userDoc),
                        ),
                      );
                    }
                  : null,
              child: Text(
                'Add Service Record Now',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isCurrentPeriod ? Colors.blue : Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -----------------------------
  // 1) Bar chart builder
  // -----------------------------
  Widget _buildBarChart(List<MapEntry<String, double>> monthlyEntries) {
    // 🧠 Handle no data case
    final hasData = monthlyEntries.any((entry) => entry.value > 0);
    if (!hasData) {
      return _buildNoDataWidget(context);
    }

    // 🧠 Correct X-axis label order
    final xLabels = _selectedDuration == 'DAYS'
        ? ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : _selectedDuration == 'MONTHS'
        ? ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5']
        : [
            'Jan',
            'Feb',
            'Mar',
            'Apr',
            'May',
            'Jun',
            'Jul',
            'Aug',
            'Sep',
            'Oct',
            'Nov',
            'Dec',
          ];

    final Map<String, double> fullData = {
      for (final label in xLabels)
        label: monthlyEntries
            .firstWhere(
              (e) => e.key == label,
              orElse: () => MapEntry(label, 0.0),
            )
            .value,
    };

    final entries = fullData.entries.toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        // 👇 compute inside LayoutBuilder (so no scope issue)
        final maxValue = entries
            .map((e) => e.value)
            .fold<double>(0, (a, b) => a > b ? a : b);

        final double maxY = ((maxValue * 1.2) / 100).ceilToDouble() * 100;
        final interval = (maxY / 5).toDouble(); // evenly spaced Y-axis lines
        final chartHeight = constraints.maxWidth * 0.6;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                _selectedDuration == 'DAYS'
                    ? 'Weekly Expenses Overview'
                    : _selectedDuration == 'MONTHS'
                    ? 'Monthly Expenses Overview'
                    : 'Yearly Expenses Overview',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: chartHeight.clamp(200, 350),
              child: BarChart(
                BarChartData(
                  maxY: maxY,
                  borderData: FlBorderData(show: false),

                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.grey.withOpacity(0.4),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),

                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: monthlyAverage,
                        color: Colors.redAccent.withOpacity(0.8),
                        strokeWidth: 2,
                        dashArray: [6, 4],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          padding: const EdgeInsets.only(right: 8, top: 4),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            backgroundColor: Colors.white,
                          ),
                          labelResolver: (line) =>
                              'Avg RM${monthlyAverage.toStringAsFixed(0)}',
                        ),
                      ),
                    ],
                  ),

                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        interval: interval,
                        getTitlesWidget: (value, meta) => Padding(
                          padding: const EdgeInsets.only(right: 5),
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
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value < 0 || value >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final label = entries[value.toInt()].key;
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              label,
                              style: const TextStyle(
                                fontSize: 11.5,
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

                  barGroups: entries.asMap().entries.map((entry) {
                    final index = entry.key;
                    final amount = entry.value.value;
                    return BarChartGroupData(
                      x: index,
                      barRods: [
                        BarChartRodData(
                          toY: amount,
                          width: 22,
                          color: index == _touchedGroupIndex
                              ? Colors.blueAccent
                              : Colors.lightBlue,
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Colors.black12,
                            width: 0.5,
                          ),
                        ),
                      ],
                      showingTooltipIndicators: index == _touchedGroupIndex
                          ? [0]
                          : [],
                    );
                  }).toList(),

                  barTouchData: BarTouchData(
                    enabled: true,
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent || event is FlLongPressEnd) {
                        setState(() {
                          if (response?.spot != null) {
                            final newIndex =
                                response!.spot!.touchedBarGroupIndex;
                            _touchedGroupIndex =
                                (newIndex == _touchedGroupIndex)
                                ? null
                                : newIndex;
                          } else {
                            _touchedGroupIndex = null;
                          }
                        });
                      }
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final label = entries[group.x.toInt()].key;
                        final amount = entries[group.x.toInt()].value;
                        final total = entries.fold<double>(
                          0.0,
                          (sum, e) => sum + e.value,
                        );
                        final percent = total > 0
                            ? (amount / total) * 100
                            : 0.0;
                        return BarTooltipItem(
                          '$label\nRM${amount.toStringAsFixed(2)} (${percent.toStringAsFixed(1)}%)',
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
    final hasData = data.values.any((v) => v > 0);

    if (!hasData) {
      return _buildNoDataWidget(context);
    }

    // ✅ Existing Pie Chart (unchanged below)
    final total = data.values.fold(0.0, (sum, v) => sum + v);
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
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
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
        if (data.length > 6)
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
