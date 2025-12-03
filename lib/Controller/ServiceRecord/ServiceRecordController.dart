import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ServiceRecordDatabase {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload image
  Future<String?> uploadServiceImage(Uint8List bytes) async {
    try {
      final fileName = 'service_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('service_images')
          .child(fileName);
      final metadata = SettableMetadata(contentType: 'image/jpeg');
      final uploadTask = storageRef.putData(bytes, metadata);
      final snapshot = await uploadTask;
      final publicUrl = await snapshot.ref.getDownloadURL();
      print('✅ Uploaded image to Firebase Storage: $publicUrl');
      return publicUrl;
    } on FirebaseException catch (e) {
      print('❌ Firebase Image upload failed: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      print('❌ General Image upload failed: $e');
      return null;
    }
  }

  /// Add a new service record
  Future<void> addServiceRecord({
    required String uid,
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
        'uid': uid,
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

  /// Unified stream with filters: category, vehicle, dateRange, sortBy
  Stream<List<Map<String, dynamic>>> getServiceRecords({
    required String uid,
    String? category,
    String? vehicleId,
    DateTimeRange? dateRange,
    String sortBy = "date", // use "date" or "amount"
  }) {
    Query query = _firestore
        .collection('ServiceRecord')
        .where('uid', isEqualTo: uid);

    // Category filter
    if (category != null && category != "All") {
      query = query.where('category', isEqualTo: category);
    }

    // Vehicle filter
    if (vehicleId != null && vehicleId != "All") {
      query = query.where('vehicleId', isEqualTo: vehicleId);
    }

    // Date range filter (expects date stored as 'yyyy-MM-dd' string)
    if (dateRange != null) {
      final start = _formatDate(dateRange.start);
      final end = _formatDate(dateRange.end);

      query = query
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThanOrEqualTo: end);
    }

    // Sorting: Firestore requires that if you use range filters on a field,
    // you should also orderBy that field (we order by date by default).
    if (sortBy == "amount") {
      query = query.orderBy('amount', descending: true);
    } else {
      // default sort by date (newest first)
      query = query.orderBy('date', descending: true);
    }

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {'id': doc.id, ...data};
      }).toList();
    });
  }

  /// Helper: format DateTime to 'yyyy-MM-dd' string used in Firestore
  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Delete a service record
  Future<void> deleteServiceRecord(String recordId) async {
    await _firestore.collection('ServiceRecord').doc(recordId).delete();
  }
}
