import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class FuelEntryDatabase {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// -----------------------------
  /// 🔵 Upload fuel receipt image
  /// -----------------------------
  Future<String?> uploadFuelImage(Uint8List bytes) async {
    try {
      final fileName = 'fuel_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('fuel_images')
          .child(fileName);

      final metadata = SettableMetadata(contentType: 'image/jpeg');

      final uploadTask = storageRef.putData(bytes, metadata);
      final snapshot = await uploadTask;

      final publicUrl = await snapshot.ref.getDownloadURL();
      print('✅ Uploaded fuel image: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Failed to upload fuel image: $e');
      return null;
    }
  }

  /// -----------------------------
  /// 🔵 Add New Fuel Entry
  /// -----------------------------
  Future<void> addFuelEntry({
    required String uid,
    required String vehicleId,
    required double amount,
    required double volumeL,
    required double pricePerLiter,
    required String fuelType,
    required String station,
    required int mileage,
    required String date, // yyyy-MM-dd
    required bool isFullTank,
    String? imgURL,
  }) async {
    try {
      await _firestore.collection('FuelEntry').add({
        'uid': uid,
        'vehicleId': vehicleId,
        'category': 'fuel', // 🔥 required
        'amount': amount,
        'volumeL': volumeL,
        'pricePerLiter': pricePerLiter,
        'fuelType': fuelType,
        'station': station,
        'mileage': mileage,
        'date': date,
        'isFullTank': isFullTank,
        'imgURL': imgURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("✅ Fuel entry added successfully.");
    } catch (e) {
      print("❌ Error adding fuel entry: $e");
      rethrow;
    }
  }

  /// ----------------------------------------
  /// 🔵 Convert DateTime to yyyy-MM-dd
  /// ----------------------------------------
  String formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
