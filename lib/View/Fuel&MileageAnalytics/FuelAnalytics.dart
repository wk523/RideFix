// FuelAnalyticsPage.dart
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceController.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../Model/vehicle_maintenance_model.dart';

class FuelAnalyticsPage extends StatefulWidget {
  final DocumentSnapshot userDoc;
  const FuelAnalyticsPage({super.key, required this.userDoc});

  @override
  State<FuelAnalyticsPage> createState() => _FuelAnalyticsPageState();
}

class _FuelAnalyticsPageState extends State<FuelAnalyticsPage> {
  String _selectedDuration = 'MONTHS'; // DAYS | MONTHS | YEARS
  DateTime _currentDate = DateTime.now();
  String _currentPeriodLabel = '';
  bool _isBarChart =
      true; // Renaming this variable may be better, but for now we keep it to toggle between the two main charts (Line/Bar) and Pie. true = Line chart.
  bool _loading = true;
  bool showAll = false;

  // Aggregated data

  // NEW structure (multi-vehicle):
  Map<String, List<MapEntry<String, double>>> _multiVehicleEfficiencyData = {};
  Map<String, double> _volumeByFuelType = {}; // fuelType -> total volume
  double _avgEfficiency = 0.0;
  double _totalVolume = 0.0;
  double _totalDistanceEstimate = 0.0;
  List<Map<String, dynamic>> _vehicleVolumeAndCost =
      []; // Used for Pie Chart: Volume/Cost by Vehicle

  // vehicle filter: Changed to a Set for multi-selection
  Set<String> _selectedVehicleIds = {};
  final VehicleDataService _vehicleSvc = VehicleDataService();
  // Map of vehicleId to full name/description for display
  Map<String, String> _vehicleNames = {};
  // List of all vehicles fetched for the dialog
  List<Vehicle> _allVehicles = [];

  late final String uid;

  @override
  void initState() {
    super.initState();
    uid = FirebaseAuth.instance.currentUser!.uid;
    _updatePeriodLabel();
    _loadVehicles(); // populate vehicleNames for dropdown
    _loadAnalyticsData();
  }

  void _updatePeriodLabel() {
    if (_selectedDuration == 'YEARS') {
      _currentPeriodLabel = '${_currentDate.year}';
    } else if (_selectedDuration == 'MONTHS') {
      _currentPeriodLabel = DateFormat('MMM yyyy').format(_currentDate);
    } else {
      final startOfWeek = _currentDate.subtract(
        Duration(days: _currentDate.weekday - 1),
      );
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      _currentPeriodLabel =
          '${DateFormat('d MMM').format(startOfWeek)} - ${DateFormat('d MMM').format(endOfWeek)}';
    }
  }

  Future<void> _loadVehicles() async {
    final list = await _vehicleSvc.readVehicleData();
    setState(() {
      _allVehicles = list;
      _vehicleNames = {
        for (var v in list)
          v.vehicleId: "${v.brand} ${v.model} (${v.plateNumber})",
      };
      // Optionally select all vehicles by default
      if (_selectedVehicleIds.isEmpty) {
        _selectedVehicleIds = _vehicleNames.keys.toSet();
      }
    });
  }

  // compute start & end DateTimes for querying createdAt
  DateTimeRange _periodRange() {
    if (_selectedDuration == 'YEARS') {
      final start = DateTime(_currentDate.year, 1, 1);
      final end = DateTime(_currentDate.year, 12, 31, 23, 59, 59);
      return DateTimeRange(start: start, end: end);
    } else if (_selectedDuration == 'MONTHS') {
      final start = DateTime(_currentDate.year, _currentDate.month, 1);
      final end = DateTime(
        _currentDate.year,
        _currentDate.month + 1,
        1,
      ).subtract(const Duration(seconds: 1));
      return DateTimeRange(start: start, end: end);
    } else {
      final start = _currentDate.subtract(
        Duration(days: _currentDate.weekday - 1),
      );
      final end = start.add(
        const Duration(days: 6, hours: 23, minutes: 59, seconds: 59),
      );
      return DateTimeRange(start: start, end: end);
    }
  }

  Future<void> _loadAnalyticsData() async {
    setState(() => _loading = true);

    final range = _periodRange();

    Query q = FirebaseFirestore.instance
        .collection('FuelEntry')
        .where('uid', isEqualTo: uid)
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(range.start),
        )
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(range.end));

    if (_selectedVehicleIds.isNotEmpty &&
        _selectedVehicleIds.length != _vehicleNames.length) {
      q = q.where('vehicleId', whereIn: _selectedVehicleIds.toList());
    }

    final snap = await q.get();

    // Reset aggregated data
    _multiVehicleEfficiencyData.clear();
    _volumeByFuelType.clear();
    _avgEfficiency = 0.0; // Resetting overall average
    _totalVolume = 0.0;
    _totalDistanceEstimate = 0.0;
    _vehicleVolumeAndCost = []; // Resetting for the Pie Chart

    final docs = snap.docs.map((d) => d.data()).toList();
    // final Map<String, double> vehicleTotalCostAccumulator = {}; // Removed unused variable

    // NEW ACCUMULATORS FOR PIE CHART (Volume and Cost by Vehicle)
    final Map<String, double> vehicleTotalVolume = {};
    final Map<String, double> vehicleTotalAmount = {};

    // Build labels depending on duration
    List<String> labels;
    if (_selectedDuration == 'DAYS') {
      labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    } else if (_selectedDuration == 'MONTHS') {
      labels = ['Week 1', 'Week 2', 'Week 3', 'Week 4', 'Week 5'];
    } else {
      labels = [
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
    }

    // NEW ACCUMULATOR STRUCTURE: (for Line Chart)
    // Key: vehicleId -> Map: { label: [totalDistance, totalVolume] }
    final Map<String, Map<String, List<double>>> vehicleBucketAccumulator = {};

    for (final d in docs) {
      try {
        final map = Map<String, dynamic>.from(d as Map);

        final vehicleId = (map['vehicleId'] ?? 'UnknownVehicle')
            .toString(); // Must have a vehicleId

        // Initialize the vehicle's accumulator if not present
        if (!vehicleBucketAccumulator.containsKey(vehicleId)) {
          vehicleBucketAccumulator[vehicleId] = {};
          // Initialize buckets for the new vehicle
          for (var l in labels) {
            // [0]: totalDistance, [1]: totalVolume
            vehicleBucketAccumulator[vehicleId]![l] = [0.0, 0.0];
          }
        }

        // --- DATE RESOLUTION LOGIC ---
        DateTime entryDate;
        final date = map['date'];
        if (date is Timestamp) {
          entryDate = date.toDate();
        } else if (date is DateTime) {
          entryDate = date;
        } else if (date is String) {
          entryDate = DateTime.tryParse(date) ?? range.start;
        } else {
          final created = map['createdAt'];
          if (created is Timestamp) {
            entryDate = created.toDate();
          } else if (created is DateTime) {
            entryDate = created;
          } else {
            entryDate = range.start;
          }
        }
        // --- END DATE RESOLUTION LOGIC ---

        final double volume = (map['volume'] is num)
            ? (map['volume'] as num).toDouble()
            : double.tryParse("${map['volume']}") ?? 0.0;
        final dynamic fe = map['fuelEfficiency'];
        final double fuelEff = (fe is num)
            ? (fe as num).toDouble()
            : double.tryParse("$fe") ?? 0.0;
        // Retrieve and parse amount (cost)
        final double amount = (map['amount'] is num)
            ? (map['amount'] as num).toDouble()
            : double.tryParse("${map['amount']}") ?? 0.0;

        // Determine label
        String label = labels.first;
        if (_selectedDuration == 'DAYS') {
          label = [
            'Mon',
            'Tue',
            'Wed',
            'Thu',
            'Fri',
            'Sat',
            'Sun',
          ][entryDate.weekday - 1];
        } else if (_selectedDuration == 'MONTHS') {
          final day = entryDate.day;
          final weekIndex = ((day - 1) / 7).floor();
          label = 'Week ${weekIndex + 1}';
          if (!labels.contains(label)) label = labels.last;
        } else {
          label = DateFormat('MMM').format(entryDate);
        }

        // Ensure the accumulator has the bucket initialized (should be, but defensive check)
        if (!vehicleBucketAccumulator[vehicleId]!.containsKey(label)) {
          vehicleBucketAccumulator[vehicleId]![label] = [0.0, 0.0];
        }

        // Accumulate total volume and total distance for overall averages
        if (volume > 0) {
          _totalVolume += volume;
          // ACCUMULATE FOR PIE CHART (Volume by Vehicle)
          vehicleTotalVolume[vehicleId] =
              (vehicleTotalVolume[vehicleId] ?? 0.0) + volume;
        }

        if (amount > 0) {
          // ACCUMULATE FOR PIE CHART (Amount/Cost by Vehicle)
          vehicleTotalAmount[vehicleId] =
              (vehicleTotalAmount[vehicleId] ?? 0.0) + amount;
        }

        if (fuelEff > 0 && volume > 0) {
          _totalDistanceEstimate += (fuelEff * volume);
        }

        // ACCUMULATE BY VEHICLE AND LABEL (for Line Chart)
        if (fuelEff > 0 && volume > 0) {
          // Use recorded fuelEff to estimate distance for the bucket
          final double estimatedDistance = fuelEff * volume;
          vehicleBucketAccumulator[vehicleId]![label]![0] += estimatedDistance;
          vehicleBucketAccumulator[vehicleId]![label]![1] += volume;
        } else if (volume > 0) {
          // Only accumulate volume if efficiency is zero/missing,
          // but we must not include it in the efficiency calculation later.
          vehicleBucketAccumulator[vehicleId]![label]![1] += volume;
        }

        // PIE CHART: volume by fuelType
        final ft = (map['fuelType'] ?? 'Unknown').toString();
        _volumeByFuelType[ft] = (_volumeByFuelType[ft] ?? 0.0) + volume;
      } catch (e) {
        print("FuelAnalytics parsing error: $e");
      }
    }

    // FINAL STEP: Convert accumulated distance/volume into efficiency (km/L) per bucket per vehicle
    final Map<String, List<MapEntry<String, double>>> finalMultiVehicleData =
        {};

    vehicleBucketAccumulator.forEach((vehicleId, bucketMap) {
      final List<MapEntry<String, double>> efficiencyEntries = [];

      // Use the sorted labels to ensure the chart spots are in order
      for (final label in labels) {
        final bucket = bucketMap[label]; // [distance, volume]
        if (bucket != null) {
          final dist = bucket[0];
          final vol = bucket[1];

          double efficiency = 0.0;
          if (vol > 0 && dist > 0) {
            efficiency = dist / vol; // km/L
          }

          // Only add points with positive efficiency to avoid breaks in the line where data is non-existent
          if (efficiency > 0.0) {
            final vehicleDisplayName = _vehicleNames[vehicleId] ?? vehicleId;
            efficiencyEntries.add(MapEntry(label, efficiency));
          }
        }
      }

      // Use vehicle's display name as the key for the chart widget
      final vehicleDisplayName = _vehicleNames[vehicleId] ?? vehicleId;
      if (efficiencyEntries.isNotEmpty) {
        finalMultiVehicleData[vehicleDisplayName] = efficiencyEntries;
      }
    });

    // NEW FINAL STEP: Convert vehicle accumulators into the display list for the Pie Chart
    _vehicleVolumeAndCost.clear();
    vehicleTotalVolume.forEach((vehicleId, totalVol) {
      final totalAmt = vehicleTotalAmount[vehicleId] ?? 0.0;
      if (totalVol > 0 || totalAmt > 0) {
        _vehicleVolumeAndCost.add({
          'name': _vehicleNames[vehicleId] ?? vehicleId,
          'volume': totalVol,
          'amount': totalAmt,
        });
      }
    });

    // Compute overall average efficiency
    _avgEfficiency = (_totalVolume > 0)
        ? (_totalDistanceEstimate / _totalVolume)
        : 0.0;

    setState(() {
      _multiVehicleEfficiencyData =
          finalMultiVehicleData; // Set the new chart data
      // _efficiencyByBucket = resultMap; // Removed/Ignore
      _loading = false;
    });
  }

  void _prevPeriod() {
    setState(() {
      if (_selectedDuration == 'YEARS')
        _currentDate = DateTime(_currentDate.year - 1);
      else if (_selectedDuration == 'MONTHS')
        _currentDate = DateTime(_currentDate.year, _currentDate.month - 1);
      else
        _currentDate = _currentDate.subtract(const Duration(days: 7));
      _updatePeriodLabel();
    });
    _loadAnalyticsData();
  }

  void _nextPeriod() {
    final now = DateTime.now();
    setState(() {
      if (_selectedDuration == 'YEARS') {
        if (_currentDate.year < now.year)
          _currentDate = DateTime(_currentDate.year + 1);
      } else if (_selectedDuration == 'MONTHS') {
        if (_currentDate.year < now.year ||
            (_currentDate.year == now.year && _currentDate.month < now.month)) {
          _currentDate = DateTime(_currentDate.year, _currentDate.month + 1);
        }
      } else {
        final next = _currentDate.add(const Duration(days: 7));
        if (next.isBefore(now)) _currentDate = next;
      }
      _updatePeriodLabel();
    });
    _loadAnalyticsData();
  }

  Widget _buildFilterRow() {
    Widget durationTab(String label) {
      final selected = _selectedDuration == label;
      return GestureDetector(
        onTap: () {
          if (_selectedDuration == label) return;
          setState(() {
            _selectedDuration = label;
            _currentDate = DateTime.now();
            _updatePeriodLabel();
          });
          _loadAnalyticsData(); // Assuming this method reloads the data
        },
        child: Container(
          // Slightly reduced horizontal padding (from 10 to 8) to help save space
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: selected ? Border.all(color: Colors.blue.shade100) : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: selected ? Colors.blue[700] : Colors.black54,
              fontSize: 12,
            ),
          ),
        ),
      );
    }

    // Calculate how many vehicles are selected for the badge (assuming state variables are defined)
    final int selectedCount = _selectedVehicleIds.length;
    final int totalCount = _vehicleNames.length;
    final bool allSelected = selectedCount == totalCount;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 1. Chart toggle (Left side) - Uses minimal space
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon for Line Chart (or Bar Chart based on context)
              IconButton(
                onPressed: () => setState(() => _isBarChart = true),
                icon: Icon(
                  Icons.show_chart,
                  color: _isBarChart ? Colors.blue : Colors.black54,
                ),
              ),
              // Icon for Pie Chart (volume distribution)
              IconButton(
                onPressed: () => setState(() => _isBarChart = false),
                icon: Icon(
                  Icons.pie_chart,
                  color: !_isBarChart ? Colors.blue : Colors.black54,
                ),
              ),
            ],
          ),

          // 2. Centered duration tabs (FIX: Wrapped in Expanded)
          Expanded(
            // <-- This allows the tabs to constrain their width
            child: Row(
              mainAxisAlignment: MainAxisAlignment
                  .center, // Keep the tabs centered within this space
              children: [
                durationTab('DAYS'),
                const SizedBox(width: 4),
                durationTab('MONTHS'),
                const SizedBox(width: 4),
                durationTab('YEARS'),
              ],
            ),
          ),

          // 3. Vehicle Filter Button on right (Fixed width)
          Stack(
            children: [
              IconButton(
                onPressed: _showVehicleFilterDialog, // Assuming this is defined
                icon: Icon(
                  Icons.filter_list,
                  color: allSelected ? Colors.black54 : Colors.blue,
                ),
              ),
              if (!allSelected && totalCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      selectedCount.toString(),
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration() {
    return InputDecoration(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        const SizedBox(width: 5),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // -----------------------------------------------------------------------

  Future<void> _showVehicleFilterDialog() async {
    final allVehicleIds = _vehicleNames.keys
        .toSet(); // Set containing all vehicle IDs

    // 🔑 MODIFICATION 1: Initialize tempSelected to contain ALL vehicle IDs
    // This makes the dialog open with all vehicles selected.
    Set<String> tempSelected = Set.from(allVehicleIds);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final bottomPadding = MediaQuery.of(context).viewInsets.bottom + 16;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: bottomPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 50,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  const Center(
                    child: Text(
                      "Filter by Vehicle",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // VEHICLE SELECTION SECTION
                  _sectionHeader(Icons.directions_car, "Select Vehicles"),
                  const SizedBox(height: 10),

                  // Select All/Deselect All
                  CheckboxListTile(
                    title: Text(
                      tempSelected.length == allVehicleIds.length
                          ? "Deselect All"
                          // Changed label here as well, since initial state is Select All
                          : "Select All",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: tempSelected.length == allVehicleIds.length,
                    onChanged: (bool? newValue) {
                      setModalState(() {
                        if (newValue == true) {
                          tempSelected.addAll(allVehicleIds);
                        } else {
                          tempSelected.clear();
                        }
                      });
                    },
                    activeColor: Colors.blue,
                    contentPadding: EdgeInsets.zero,
                  ),

                  const Divider(height: 1),

                  // List of vehicles using CheckboxListTile
                  // Note: Consider wrapping this section in a Scrollable widget if the list is long
                  // to avoid issues when the keyboard is open or if the screen is small.
                  Expanded(
                    // Use Expanded to give the list flexible height
                    child: SingleChildScrollView(
                      child: Column(
                        children: _allVehicles.map((vehicle) {
                          return CheckboxListTile(
                            title: Text(
                              _vehicleNames[vehicle.vehicleId] ??
                                  'Unknown Vehicle',
                            ),
                            value: tempSelected.contains(vehicle.vehicleId),
                            onChanged: (bool? newValue) {
                              setModalState(() {
                                if (newValue == true) {
                                  tempSelected.add(vehicle.vehicleId);
                                } else {
                                  tempSelected.remove(vehicle.vehicleId);
                                }
                              });
                            },
                            activeColor: Colors.blue,
                            contentPadding: EdgeInsets.zero,
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10), // Reduced space above buttons
                  // APPLY/RESET BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        icon: const Icon(Icons.refresh, color: Colors.red),
                        label: const Text(
                          // Changed label back to "Reset"
                          "Reset",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onPressed: () {
                          // 🔑 MODIFICATION 2: Reset now clears the selection (sets to empty)
                          setModalState(() => tempSelected.clear());
                        },
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text("Apply"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          // Apply the filters and pop the dialog
                          setState(() {
                            _selectedVehicleIds = tempSelected;
                          });
                          _loadAnalyticsData();
                          Navigator.pop(context);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPeriodNavigator() => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _prevPeriod,
          icon: const Icon(Icons.arrow_back_ios, size: 16),
        ),
        Text(
          _currentPeriodLabel,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        IconButton(
          onPressed: _nextPeriod,
          icon: const Icon(Icons.arrow_forward_ios, size: 16),
        ),
      ],
    ),
  );

  Widget _buildChartArea() {
    // Use the new multi-vehicle data for the line chart availability check
    final hasLineChartData =
        _multiVehicleEfficiencyData.isNotEmpty &&
        _multiVehicleEfficiencyData.values.any((list) => list.isNotEmpty);

    // Use the pie chart data for its own check
    final hasPieChartData = _vehicleVolumeAndCost
        .isNotEmpty; // Changed to use _vehicleVolumeAndCost
    // Decide which data source to check based on the current chart type
    final bool hasData = _isBarChart ? hasLineChartData : hasPieChartData;

    if (!hasData && !_loading) return _buildNoDataWidget();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _isBarChart
                ? 'Fuel Efficiency Trend'
                : 'Fuel Volume by Vehicle', // FIXED: Updated for per-vehicle breakdown
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 4),
          if (_isBarChart)
            Text(
              'Per $_selectedDuration (Average: ${_avgEfficiency.toStringAsFixed(2)} km/L)',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          if (!_isBarChart)
            Text(
              'Total Volume: ${_totalVolume.toStringAsFixed(2)} L',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          const SizedBox(height: 16),

          GestureDetector(
            onHorizontalDragEnd: (_) {
              setState(() => _isBarChart = !_isBarChart);
            },
            child: SizedBox(
              height:
                  350, // Increased height slightly to accommodate the legend
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  // 🟢 FIX HERE: Pass the new multi-vehicle map
                  : (_isBarChart
                        ? _buildLineChart(_multiVehicleEfficiencyData)
                        : _buildPieChart()),
            ),
          ),

          const SizedBox(height: 12),
          Center(
            child: Text(
              '← Swipe to view ${_isBarChart ? "Fuel Volume by Vehicle" : "Efficiency Trend"} →',
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

  final List<Color> _vehicleColors = [
    Colors.blue,
    Colors.orange,
    Colors.green,
    Colors.red,
    Colors.purple,
    Colors.brown,
  ];

  Widget _buildLineChart(
    Map<String, List<MapEntry<String, double>>> vehicleEntriesMap,
  ) {
    // Check if there is any data at all
    if (vehicleEntriesMap.isEmpty) {
      return const Center(child: Text("No fuel efficiency data available."));
    }

    // 1. --- CONSOLIDATE ALL LABELS and VALUES ---
    // Get all unique date labels (X-axis labels)
    final labels = <String>{};
    vehicleEntriesMap.values.forEach((list) {
      labels.addAll(list.map((e) => e.key));
    });
    final sortedLabels = labels.toList()..sort();
    final nonZeroValues = vehicleEntriesMap.values
        .expand((list) => list.map((e) => e.value))
        .where((v) => v > 0)
        .toList();

    // If no data points have efficiency > 0, show error
    if (nonZeroValues.isEmpty) {
      return const Center(
        child: Text("No full tank fuel efficiency data available."),
      );
    }

    // Create a mapping from label string to X-axis index (0, 1, 2, ...)
    final labelToIndexMap = {
      for (var i = 0; i < sortedLabels.length; i++) sortedLabels[i]: i,
    };

    // 2. --- Y-AXIS DYNAMIC RANGE CALCULATION ---
    final maxVal = nonZeroValues.fold<double>(0.0, (p, n) => n > p ? n : p);
    final minVal = nonZeroValues.fold<double>(maxVal, (p, n) => n < p ? n : p);

    final minY = 0.0;
    final maxY = (maxVal * 1.1).clamp(minVal + 2.0, maxVal + 10.0);

    // --- Y-AXIS INTERVAL CALCULATION ---
    double interval = 1.0;
    if (maxY > 15) {
      interval = 2.0;
    } else if (maxY < 5) {
      interval = 0.5;
    }
    // Clamp minVal to 0 for display
    // final chartMinY = (minVal * 0.9).clamp(0.0, minVal);

    // 3. --- CREATE LINE CHART BAR DATA FOR EACH VEHICLE ---
    final List<LineChartBarData> lineBarsData = [];
    int colorIndex = 0;

    vehicleEntriesMap.forEach((vehicleName, entries) {
      final Color lineColor =
          _vehicleColors[colorIndex % _vehicleColors.length];
      colorIndex++;

      final List<FlSpot> spots = [];

      // Create a temporary map to easily look up value by date string
      final entryMap = {for (var e in entries) e.key: e.value};

      // Iterate over the consolidated (sorted) labels to ensure all lines
      // align on the same X-coordinates.
      for (int i = 0; i < sortedLabels.length; i++) {
        final label = sortedLabels[i];
        final value = entryMap[label];

        // If no data exists for this vehicle on this date, the value will be null.
        // We only add a spot if the value is valid (e.g., > 0)
        if (value != null && value > 0) {
          spots.add(FlSpot(i.toDouble(), value));
        } else {
          // For missing/zero values, you might want to skip,
          // or add FlSpot(i.toDouble(), null) if FlSpot supported it
          // to create a break. Since FlSpot requires double, skipping is safest.
        }
      }

      if (spots.isNotEmpty) {
        lineBarsData.add(
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                radius: 4,
                color: lineColor,
                strokeWidth: 1,
                strokeColor: Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: false, // Turn off area below the line for multi-line charts
            ),
          ),
        );
      }
    });

    // 4. --- BUILD THE CHART WIDGET ---
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Chart body container
        SizedBox(
          // FIX: Reduced height to prevent bottom overflow
          // (Original was 300, reducing to 280-290 should help)
          height: 280,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              titlesData: FlTitlesData(
                show: true,
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),

                // Left Y-Axis Titles (Efficiency) - remains the same
                leftTitles: AxisTitles(
                  axisNameWidget: const Text(
                    'km/L',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  axisNameSize: 20,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 38,
                    interval: interval,
                    getTitlesWidget: (value, meta) {
                      if (value < minY ||
                          value > maxY ||
                          ((value - minY).abs() % interval).abs() > 0.001) {
                        return const Text('');
                      }
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          value.toStringAsFixed(value == value.toInt() ? 0 : 1),
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),

                // Bottom X-Axis Titles (Time Buckets) - MODIFIED for less reserved space
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    // FIX: Reduced reserved space from 55 to 45
                    reservedSize: 45,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= sortedLabels.length) {
                        return const SizedBox.shrink();
                      }
                      final labelText = sortedLabels[idx];

                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Transform.rotate(
                          angle: -45 * (pi / 180),
                          alignment: Alignment.topLeft,
                          child: Text(
                            labelText,
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Grid Lines (kept the same logic)
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (value) {
                  if (((value - minY) % interval).abs() < 0.001 &&
                      value >= minY) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.4),
                      strokeWidth: 1,
                    );
                  }
                  return FlLine(color: Colors.transparent, strokeWidth: 0);
                },
              ),

              borderData: FlBorderData(
                show: true,
                border: Border.all(
                  color: Colors.grey.withOpacity(0.4),
                  width: 1,
                ),
              ),

              // Line Touch Data (updated to display Vehicle Name)
              lineTouchData: LineTouchData(
                enabled: true,
                touchTooltipData: LineTouchTooltipData(
                  fitInsideHorizontally: true,
                  getTooltipItems: (touchedSpots) {
                    return touchedSpots.map((LineBarSpot touchedSpot) {
                      final vehicleName = vehicleEntriesMap.keys
                          .toList()[touchedSpot.barIndex];
                      final label = sortedLabels[touchedSpot.x.toInt()];
                      final value = touchedSpot.y;

                      return LineTooltipItem(
                        '$vehicleName\n$label\n${value > 0.0 ? value.toStringAsFixed(2) + " km/L" : "N/A"}',
                        TextStyle(
                          color: touchedSpot
                              .bar
                              .color, // Tooltip text color matches line color
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),

              // 4. Set the LineBarsData to the list of vehicle lines
              lineBarsData: lineBarsData,
            ),
          ),
        ),

        // 5. Add a simple legend (below the chart)
        const SizedBox(height: 8),
        // FIX: Ensure _buildLegend uses a layout that won't overflow
        _buildLegend(vehicleEntriesMap.keys.toList()),
      ],
    );
  }

  // 6. --- LEGEND WIDGET ---
  Widget _buildLegend(List<String> vehicleNames) {
    return Wrap(
      // Use Wrap to allow the legend items to flow to the next line if space is tight
      spacing: 12.0,
      runSpacing: 4.0,
      alignment: WrapAlignment.center,
      children: vehicleNames.asMap().entries.map((entry) {
        final int index = entry.key;
        final String name = entry.value;
        final Color color = _vehicleColors[index % _vehicleColors.length];

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              name,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPieChart() {
    final List<Map<String, dynamic>> rawData = _vehicleVolumeAndCost;

    if (rawData.isEmpty) {
      return const Center(
        child: Text('No fuel data available for any vehicle in this period.'),
      );
    }

    // Calculate total volume for percentage calculation
    final totalVolume = rawData.fold(
      0.0,
      (sum, vehicle) => sum + (vehicle['volume'] as double),
    );

    // Limit data for display if showAll is false
    final limitedData = showAll ? rawData : rawData.take(6).toList();

    // Colors for the pie chart sections
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
    ];

    final sections = limitedData.asMap().entries.map((entry) {
      final idx = entry.key;
      final data = entry.value;
      final vehicleVolume = data['volume'] as double;
      final color = colors[idx % colors.length];
      final percentage = (vehicleVolume / totalVolume * 100);

      // Create PieChartSectionData based on VOLUME
      return PieChartSectionData(
        color: color,
        value: vehicleVolume,
        // FIX 1: Display percentage only, or make it slightly descriptive.
        // Only show the label if the slice is large enough (e.g., > 4%)
        title: percentage > 4.0 ? '${percentage.toStringAsFixed(1)}%' : '',

        // FIX 2: Reduced radius for a smaller chart
        radius: 65,

        titleStyle: const TextStyle(
          // FIX 3: Smaller, white font for better visibility on dark colors
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        // FIX 4: Pull the text back slightly to fit on small slices
        titlePositionPercentageOffset: 0.55,
      );
    }).toList();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // PIE CHART (LEFT)
            SizedBox(
              // FIX 5: Reduced size to 170x170 (matches previous recommendation)
              height: 170,
              width: 170,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 20,
                  sectionsSpace: 1, // Reduced section space slightly
                ),
              ),
            ),

            // FIX 6: Reduced spacing between chart and legend
            const SizedBox(width: 12),

            // LEGEND (RIGHT)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: limitedData.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final data = entry.value;
                  final vehicleName = data['name'] as String;
                  final volume = (data['volume'] as double).toStringAsFixed(2);
                  final amount = (data['amount'] as double).toStringAsFixed(2);
                  final color = colors[idx % colors.length];

                  return Padding(
                    padding: const EdgeInsets.only(
                      bottom: 6.0,
                    ), // Reduced bottom padding
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Color indicator
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Legend Text (Vehicle Name + Volume + Amount)
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                vehicleName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              // FIX 7: Enhanced legend detail with volume and cost
                              Text(
                                '${volume} L (RM${amount})',
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),

        // Show All button remains below the Row
        if (rawData.length > 6)
          TextButton(
            onPressed: () => setState(() => showAll = !showAll),
            child: Text(showAll ? 'Show less' : 'Show all'),
          ),
      ],
    );
  }

  Widget _buildNoDataWidget() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'No fuel efficiency data for this period.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Try changing the period or selecting a vehicle.',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Fuel Analytics',
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
              _buildFilterRow(),
              _buildPeriodNavigator(),
              _buildChartArea(),
              const SizedBox(height: 12),
              // small summary card row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.06),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Estimated Distance',
                            style: TextStyle(color: Colors.black54),
                          ),
                          Text(
                            '${_totalDistanceEstimate.toStringAsFixed(1)} km',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Avg Efficiency',
                            style: TextStyle(color: Colors.black54),
                          ),
                          Text(
                            _avgEfficiency > 0
                                ? '${_avgEfficiency.toStringAsFixed(2)} km/L'
                                : 'N/A',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
