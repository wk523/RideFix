import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceRecordDatabase {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// ✅ Upload image to Supabase (stored in 'service_images' bucket)
  Future<String?> uploadServiceImage(Uint8List bytes) async {
    try {
      final fileName = 'service_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final res = await Supabase.instance.client.storage
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
        data.addAll(extraData); // ✅ safe merge
      }

      await _firestore
          .collection('ServiceRecord')
          .doc(category)
          .collection('records')
          .add(data);

      print("✅ Service record added successfully under category: $category");
    } catch (e) {
      print("❌ Error adding service record: $e");
      rethrow;
    }
  }

  /// ✅ Fetch all service records for a specific category
  Future<List<Map<String, dynamic>>> fetchServiceRecordsByCategory({
    required String category,
  }) async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('ServiceRecord')
          .doc(category)
          .collection('records')
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => {'id': doc.id, ...doc.data() as Map<String, dynamic>})
          .toList();
    } catch (e) {
      print("❌ Error fetching records: $e");
      return [];
    }
  }

  /// ✅ Fetch all service records (from all categories)
  Future<List<Map<String, dynamic>>> fetchAllServiceRecords() async {
    try {
      List<Map<String, dynamic>> allRecords = [];

      final categories = await _firestore.collection('ServiceRecord').get();

      for (var catDoc in categories.docs) {
        final categoryName = catDoc.id;
        final recordsSnapshot = await _firestore
            .collection('ServiceRecord')
            .doc(categoryName)
            .collection('records')
            .orderBy('createdAt', descending: true)
            .get();

        for (var record in recordsSnapshot.docs) {
          allRecords.add({
            'category': categoryName,
            'id': record.id,
            ...record.data() as Map<String, dynamic>,
          });
        }
      }

      return allRecords;
    } catch (e) {
      print("❌ Error fetching all records: $e");
      return [];
    }
  }

  /// ✅ Delete a specific service record
  Future<void> deleteServiceRecord({
    required String category,
    required String recordId,
  }) async {
    try {
      await _firestore
          .collection('ServiceRecord')
          .doc(category)
          .collection('records')
          .doc(recordId)
          .delete();

      print("🗑️ Service record deleted successfully from $category");
    } catch (e) {
      print("❌ Error deleting record: $e");
      rethrow;
    }
  }
}
