import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExpensesAnalyticsDatabase {
  final CollectionReference _serviceRecords = FirebaseFirestore.instance
      .collection('ServiceRecord');
  // Collection reference for FuelEntry
  final CollectionReference _fuelRecords = FirebaseFirestore.instance
      .collection('FuelEntry');

  // --- Helper to Fetch and Merge Records ---

  /// Fetches records from both ServiceRecord and FuelEntry collections for the given user,
  /// ensuring FuelEntry items are labeled with the category 'Fuel'.
  Future<List<Map<String, dynamic>>> _fetchAllRecords({
    required String uid,
    // New optional filter parameters
    List<String>? categories,
    String? vehicleId,
  }) async {
    // 1. Base Query with UID
    Query serviceQuery = _serviceRecords.where('uid', isEqualTo: uid);
    Query fuelQuery = _fuelRecords.where('uid', isEqualTo: uid);

    // 2. Apply Vehicle Filter (applies to both)
    if (vehicleId != null && vehicleId.isNotEmpty) {
      serviceQuery = serviceQuery.where('vehicleId', isEqualTo: vehicleId);
      fuelQuery = fuelQuery.where('vehicleId', isEqualTo: vehicleId);
    }

    // 3. Apply Category Filters
    // Note: 'Fuel' is handled separately as it's not a ServiceRecord category.
    final serviceCategories =
        categories?.where((c) => c != 'Fuel').toList() ?? [];
    final filterFuel = categories == null || categories.contains('Fuel');

    if (serviceCategories.isNotEmpty) {
      // Filter Service Records by category list
      serviceQuery = serviceQuery.where('category', whereIn: serviceCategories);
    } else if (categories != null &&
        categories.isNotEmpty &&
        !categories.contains('Fuel')) {
      // If categories is provided, but 'Fuel' is not present, AND no service categories were selected,
      // then the service record snapshot should be empty (or the query will fail if categories is empty).
      // To avoid Firebase query limitations, we'll manually check the filter later if serviceCategories is empty.
    }

    // 4. Fetch Snapshots
    final serviceSnapshot = await serviceQuery.get();
    final fuelSnapshot = filterFuel ? await fuelQuery.get() : null;

    List<Map<String, dynamic>> allRecords = [];

    // Add Service Records
    for (var doc in serviceSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      // Secondary manual filter if needed (though Firebase query should handle it)
      if (serviceCategories.isEmpty &&
          categories != null &&
          categories.isNotEmpty &&
          !categories.contains(data['category'])) {
        continue; // Skip if it's not the required service category (unlikely, but safe)
      }
      allRecords.add(data);
    }

    // Add Fuel Entries, forcing category to 'Fuel'
    if (filterFuel && fuelSnapshot != null) {
      for (var doc in fuelSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        data['category'] = 'Fuel';
        allRecords.add(data);
      }
    }

    return allRecords;
  }

  // --- Core Analytics Functions ---

  /// Returns summary grouped by selected duration (Day/Week/Month).
  Future<Map<String, dynamic>> fetchExpenseSummary({
    required String uid,
    required String duration,
    required DateTime referenceDate,
    List<String>? categories,
    String? vehicleId,
  }) async {
    final allRecords = await _fetchAllRecords(
      uid: uid,
      categories: categories,
      vehicleId: vehicleId,
    );

    final Map<String, double> groupedTotals = {};

    // 1. Define time range based on duration
    late DateTime startDate;
    late DateTime endDate;

    if (duration == 'DAYS') {
      startDate = referenceDate.subtract(
        Duration(days: referenceDate.weekday - 1),
      );
      endDate = startDate.add(const Duration(days: 6));
    } else if (duration == 'MONTHS') {
      startDate = DateTime(referenceDate.year, referenceDate.month, 1);
      // Last day of the current month
      endDate = DateTime(referenceDate.year, referenceDate.month + 1, 0);
    } else {
      // YEARS
      startDate = DateTime(referenceDate.year, 1, 1);
      endDate = DateTime(referenceDate.year, 12, 31);
    }

    // 2. Filter records and group by period
    for (final data in allRecords) {
      final amount = _parseDouble(data['amount']);

      // Parse date from record data
      DateTime? date;
      final rawDate = data['date'];
      if (rawDate is String && rawDate.isNotEmpty) {
        try {
          date = DateFormat('yyyy-MM-dd').parse(rawDate);
        } catch (_) {}
      } else if (rawDate is Timestamp) {
        date = rawDate.toDate();
      }
      if (date == null) continue;

      // Filter only entries within range
      if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

      late String key;
      if (duration == 'DAYS') {
        key = DateFormat('E').format(date); // Mon, Tue, etc.
      } else if (duration == 'MONTHS') {
        final weekNumber = ((date.day - 1) / 7).floor() + 1;
        key = 'Week $weekNumber';
      } else {
        key = DateFormat('MMM').format(date); // Jan, Feb, etc.
      }

      groupedTotals[key] = (groupedTotals[key] ?? 0.0) + amount;
    }

    // 3. Fill missing labels for completeness
    if (duration == 'DAYS') {
      for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        groupedTotals.putIfAbsent(d, () => 0.0);
      }
    } else if (duration == 'MONTHS') {
      final daysInMonth = DateTime(
        referenceDate.year,
        referenceDate.month + 1,
        0,
      ).day;
      final weeksInMonth = ((daysInMonth - 1) ~/ 7) + 1;
      for (var i = 1; i <= weeksInMonth; i++) {
        groupedTotals.putIfAbsent('Week $i', () => 0.0);
      }
    } else {
      for (final m in [
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
      ]) {
        groupedTotals.putIfAbsent(m, () => 0.0);
      }
    }

    // 4. Calculate Summary Metrics
    final total = groupedTotals.values.fold(0.0, (a, b) => a + b);
    final bucketCount = duration == 'DAYS'
        ? 7
        : duration == 'MONTHS'
        ? ((DateTime(referenceDate.year, referenceDate.month + 1, 0).day - 1) ~/
                  7) +
              1
        : 12;
    final average = bucketCount > 0 ? total / bucketCount : 0.0;
    final tco = average * 6;

    // 5. Sort logically by label order
    final sortedKeys = groupedTotals.keys.toList()
      ..sort((a, b) {
        if (duration == 'DAYS') {
          const order = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          return order.indexOf(a).compareTo(order.indexOf(b));
        } else if (duration == 'MONTHS') {
          final ai = int.tryParse(a.replaceAll('Week ', '')) ?? 0;
          final bi = int.tryParse(b.replaceAll('Week ', '')) ?? 0;
          return ai.compareTo(bi);
        } else {
          const months = {
            'Jan': 1,
            'Feb': 2,
            'Mar': 3,
            'Apr': 4,
            'May': 5,
            'Jun': 6,
            'Jul': 7,
            'Aug': 8,
            'Sep': 9,
            'Oct': 10,
            'Nov': 11,
            'Dec': 12,
          };
          return (months[a] ?? 0).compareTo(months[b] ?? 0);
        }
      });

    final sortedMap = {for (var k in sortedKeys) k: groupedTotals[k]!};

    return {
      'total': total,
      'groupedTotals': sortedMap,
      'average': average,
      'tco': tco,
    };
  }

  /// 🔮 Predicts future total cost (TCO) for next 6 months
  /// using linear regression based on historical monthly totals.
  Future<Map<String, dynamic>> predictTCO({required String uid}) async {
    final allRecords = await _fetchAllRecords(uid: uid);

    // Step 1: Build monthly totals (past 12 months)
    final Map<String, double> monthlyTotals = {};
    for (final data in allRecords) {
      final amount = _parseDouble(data['amount']);

      DateTime? date;
      final rawDate = data['date'];
      if (rawDate is String && rawDate.isNotEmpty) {
        try {
          date = DateFormat('yyyy-MM-dd').parse(rawDate);
        } catch (_) {}
      } else if (rawDate is Timestamp) {
        date = rawDate.toDate();
      } else if (data['createdAt'] is Timestamp) {
        date = (data['createdAt'] as Timestamp).toDate();
      }
      if (date == null) continue;

      final key = DateFormat('yyyy-MM').format(date);
      monthlyTotals[key] = (monthlyTotals[key] ?? 0.0) + amount;
    }

    if (monthlyTotals.isEmpty) {
      return {'predictedTotal': 0.0, 'monthlyProjection': List.filled(6, 0.0)};
    }

    // Step 2-5: Linear Regression and Prediction (unchanged)
    final sortedKeys = monthlyTotals.keys.toList()
      ..sort((a, b) => a.compareTo(b));
    final values = sortedKeys.map((k) => monthlyTotals[k]!).toList();
    final recentValues = values.length > 12
        ? values.sublist(values.length - 12)
        : values;
    final n = recentValues.length;

    final xVals = List.generate(n, (i) => i + 1);
    final xMean = xVals.reduce((a, b) => a + b) / n;
    final yMean = recentValues.reduce((a, b) => a + b) / n;

    double nume = 0.0, deno = 0.0;
    for (int i = 0; i < n; i++) {
      nume += (xVals[i] - xMean) * (recentValues[i] - yMean);
      deno += (xVals[i] - xMean) * (xVals[i] - xMean);
    }
    final slope = deno == 0 ? 0.0 : nume / deno;
    final intercept = yMean - slope * xMean;

    final predictions = <double>[];
    for (int i = n + 1; i <= n + 6; i++) {
      final y = intercept + slope * i;
      predictions.add(y < 0 ? 0.0 : y);
    }

    final predictedTotal = predictions.fold(0.0, (a, b) => a + b);
    return {'predictedTotal': predictedTotal, 'monthlyProjection': predictions};
  }

  /// Returns a Map<Category, sumAmount> filtered by duration (for PieChart)
  Future<Map<String, double>> fetchExpensesByCategory({
    required String uid,
    required String duration,
    required DateTime referenceDate,
    // Pass-through filters
    List<String>? categories,
    String? vehicleId,
  }) async {
    // MODIFIED: Pass filters to _fetchAllRecords
    final allRecords = await _fetchAllRecords(
      uid: uid,
      categories: categories,
      vehicleId: vehicleId,
    );
    final Map<String, double> map = {};

    late DateTime startDate;
    late DateTime endDate;

    // Define time range based on duration (same logic as summary)
    if (duration == 'DAYS') {
      startDate = referenceDate.subtract(
        Duration(days: referenceDate.weekday - 1),
      );
      endDate = startDate.add(const Duration(days: 6));
    } else if (duration == 'MONTHS') {
      startDate = DateTime(referenceDate.year, referenceDate.month, 1);
      endDate = DateTime(referenceDate.year, referenceDate.month + 1, 0);
    } else {
      startDate = DateTime(referenceDate.year, 1, 1);
      endDate = DateTime(referenceDate.year, 12, 31);
    }

    for (final data in allRecords) {
      // Category is guaranteed to be present and correct due to _fetchAllRecords
      final category = (data['category'] ?? 'Unknown').toString();
      final amount = _parseDouble(data['amount']);

      DateTime? date;
      final rawDate = data['date'];
      if (rawDate is String && rawDate.isNotEmpty) {
        try {
          date = DateFormat('yyyy-MM-dd').parse(rawDate);
        } catch (_) {}
      } else if (rawDate is Timestamp) {
        date = rawDate.toDate();
      } else if (data['createdAt'] is Timestamp) {
        date = (data['createdAt'] as Timestamp).toDate();
      }
      if (date == null) continue;

      // Only include entries within the target date range
      if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

      map[category] = (map[category] ?? 0.0) + amount;
    }

    return map;
  }

  // --- Utility ---

  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
