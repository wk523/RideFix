import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ExpensesAnalyticsDatabase {
  final CollectionReference _records =
      FirebaseFirestore.instance.collection('ServiceRecord');

  /// Returns summary by selected duration:
  /// 'DAYS'  -> group by day (Mon..Sun)
  /// 'MONTHS'-> group by week (Week 1..Week N)
  /// 'YEARS' -> group by month (Jan..Dec)
  Future<Map<String, dynamic>> fetchExpenseSummary({
    required String userId,
    required String duration,
    required DateTime referenceDate, // ✅ Added parameter
  }) async {
    final snapshot = await _records.where('userId', isEqualTo: userId).get();

    final Map<String, double> groupedTotals = {};

    // ✅ Define time range using referenceDate (so ← → navigation works)
    late DateTime startDate;
    late DateTime endDate;

    if (duration == 'DAYS') {
      startDate = referenceDate.subtract(Duration(days: referenceDate.weekday - 1));
      endDate = startDate.add(const Duration(days: 6));
    } else if (duration == 'MONTHS') {
      startDate = DateTime(referenceDate.year, referenceDate.month, 1);
      endDate = DateTime(referenceDate.year, referenceDate.month + 1, 0);
    } else {
      startDate = DateTime(referenceDate.year, 1, 1);
      endDate = DateTime(referenceDate.year, 12, 31);
    }

    // 🔄 Filter records and group by period
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = _parseDouble(data['amount']);

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

      // ✅ Filter only entries within range
      if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

      late String key;
      if (duration == 'DAYS') {
        key = DateFormat('E').format(date);
      } else if (duration == 'MONTHS') {
        final weekNumber = ((date.day - 1) / 7).floor() + 1;
        key = 'Week $weekNumber';
      } else {
        key = DateFormat('MMM').format(date);
      }

      groupedTotals[key] = (groupedTotals[key] ?? 0.0) + amount;
    }

    // Fill missing labels for completeness
    if (duration == 'DAYS') {
      for (final d in ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']) {
        groupedTotals.putIfAbsent(d, () => 0.0);
      }
    } else if (duration == 'MONTHS') {
      final daysInMonth = DateTime(referenceDate.year, referenceDate.month + 1, 0).day;
      final weeksInMonth = ((daysInMonth - 1) ~/ 7) + 1;
      for (var i = 1; i <= weeksInMonth; i++) {
        groupedTotals.putIfAbsent('Week $i', () => 0.0);
      }
    } else {
      for (final m in [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ]) {
        groupedTotals.putIfAbsent(m, () => 0.0);
      }
    }

    final total = groupedTotals.values.fold(0.0, (a, b) => a + b);
    final bucketCount = duration == 'DAYS'
        ? 7
        : duration == 'MONTHS'
            ? ((DateTime(referenceDate.year, referenceDate.month + 1, 0).day - 1) ~/ 7) + 1
            : 12;
    final average = bucketCount > 0 ? total / bucketCount : 0.0;
    final tco = average * 6;

    // Sort logically by label order
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
            'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
            'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
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
  Future<Map<String, dynamic>> predictTCO({
    required String userId,
  }) async {
    final snapshot = await _records.where('userId', isEqualTo: userId).get();

    // Step 1: Build monthly totals (past 12 months)
    final Map<String, double> monthlyTotals = {};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
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
      return {
        'predictedTotal': 0.0,
        'monthlyProjection': List.filled(6, 0.0),
      };
    }

    // Step 2: Sort months chronologically
    final sortedKeys = monthlyTotals.keys.toList()..sort((a, b) => a.compareTo(b));
    final values = sortedKeys.map((k) => monthlyTotals[k]!).toList();

    // Step 3: Keep only last 12 months
    final recentValues = values.length > 12 ? values.sublist(values.length - 12) : values;
    final n = recentValues.length;

    // Step 4: Linear regression
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

    // Step 5: Predict next 6 months
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
    required String userId,
    required String duration,
    required DateTime referenceDate, // ✅ Added parameter
  }) async {
    final snapshot = await _records.where('userId', isEqualTo: userId).get();
    final Map<String, double> map = {};

    late DateTime startDate;
    late DateTime endDate;

    if (duration == 'DAYS') {
      startDate = referenceDate.subtract(Duration(days: referenceDate.weekday - 1));
      endDate = startDate.add(const Duration(days: 6));
    } else if (duration == 'MONTHS') {
      startDate = DateTime(referenceDate.year, referenceDate.month, 1);
      endDate = DateTime(referenceDate.year, referenceDate.month + 1, 0);
    } else {
      startDate = DateTime(referenceDate.year, 1, 1);
      endDate = DateTime(referenceDate.year, 12, 31);
    }

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
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

      // ✅ Only include entries within the target date range
      if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

      map[category] = (map[category] ?? 0.0) + amount;
    }

    return map;
  }

  double _parseDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }
}
