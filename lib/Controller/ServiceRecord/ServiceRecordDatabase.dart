import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:async/async.dart';

class ServiceRecordDatabase {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Upload image to Supabase (stored in 'service_images' bucket)
  Future<String?> uploadServiceImage(Uint8List bytes) async {
    try {
      final fileName = 'service_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('service_images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('service_images')
          .getPublicUrl(fileName);

      print('✅ Uploaded image to Supabase: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Image upload failed: $e');
      return null;
    }
  }

  /// ✅ Add a new service record under the selected category
  /// ✅ Add a new service record (flat structure)
  Future<void> addServiceRecord({
    required String userId,
    required String vehicleId,
    required String category,
    required double amount,
    required String date,
    String? note,
    String? imgURL,
    Map<String, dynamic>? extraData,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'userId': userId,
        'vehicleId': vehicleId,
        'category': category,
        'amount': amount,
        'date': date,
        'note': note ?? '',
        'imgURL': imgURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      };

      if (extraData != null) {
        data.addAll(extraData);
      }

      await _firestore.collection('ServiceRecord').add(data);
      print("✅ Added record (flat structure) under category: $category");
    } catch (e) {
      print("❌ Error adding record: $e");
      rethrow;
    }
  }

  /// 🔥 REAL-TIME: Stream of records for a single category
  Stream<List<Map<String, dynamic>>> streamServiceRecordsByCategory({
    required String userId,
    required String category,
  }) {
    return _firestore
        .collection('ServiceRecord')
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: category)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// 🔍 Get Firestore query stream with filters: category, date range, sort
  Stream<List<Map<String, dynamic>>> streamFilteredServiceRecords({
    required String userId,
    String? category,
    DateTimeRange? dateRange,
    String sortBy = 'Date',
  }) {
    Query query = _firestore
        .collection('ServiceRecord')
        .where('userId', isEqualTo: userId);

    // Apply category filter
    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    // Apply date range filter
    if (dateRange != null) {
      query = query
          .where('date', isGreaterThanOrEqualTo: _formatDate(dateRange.start))
          .where('date', isLessThanOrEqualTo: _formatDate(dateRange.end));
    }

    // Apply sorting
    if (sortBy == 'Amount') {
      query = query.orderBy('amount', descending: true);
    } else {
      query = query.orderBy('date', descending: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    });
  }

  /// 🧠 Helper: Format date to match Firestore format
  String _formatDate(DateTime date) {
    return "${date.year.toString().padLeft(4, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  /// 🔥 REAL-TIME: Stream of all service records (merged from all categories)
  Stream<List<Map<String, dynamic>>> streamAllServiceRecords(String userId) {
    return _firestore
        .collection('ServiceRecord')
        .where('userId', isEqualTo: userId)
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// ✅ Delete a specific service record
  Future<void> deleteServiceRecord(String recordId) async {
    await _firestore.collection('ServiceRecord').doc(recordId).delete();
  }
}
