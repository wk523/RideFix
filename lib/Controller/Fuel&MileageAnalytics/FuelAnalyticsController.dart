import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FuelEntryDatabase {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ... (uploadFuelImage remains the same) ...
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

  /// ----------------------------------------
  /// 🔄 NEW/REPLACED FUNCTION: Get Summary Since Last Full Tank
  ///
  /// Finds the mileage of the last full tank (FT1) and sums the volume
  /// of all fuel entries recorded since that fill.
  /// ----------------------------------------
  Future<Map<String, dynamic>> getSummarySinceLastFullTank(
    String vehicleId,
  ) async {
    try {
      // 1. Find the last Full Tank entry (FT1)
      final lastFullTankQuery = await _firestore
          .collection('FuelEntry')
          .where('vehicleId', isEqualTo: vehicleId)
          .where('isFullTank', isEqualTo: true)
          // Sort by mileage descending to find the most recent one
          .orderBy('mileage', descending: true)
          .limit(1)
          .get();

      if (lastFullTankQuery.docs.isEmpty) {
        return {
          'lastFullTankMileage': 0,
          'lastFullTankTimestamp': null,
          'totalVolumeSinceLastFullTank': 0.0,
        };
      }

      final lastFullTankDoc = lastFullTankQuery.docs.first;
      final int lastFullTankMileage = lastFullTankDoc.data()['mileage'] as int;
      // Use the timestamp to query for all entries *after* this point.
      final Timestamp lastFullTankTimestamp =
          lastFullTankDoc.data()['createdAt'] as Timestamp;

      // 2. Sum the volumes of ALL entries that occurred AFTER FT1 (partials and others).
      // NOTE: We rely on the timestamp 'createdAt' being set correctly to order entries.
      final intermediateEntriesQuery = await _firestore
          .collection('FuelEntry')
          .where('vehicleId', isEqualTo: vehicleId)
          // Filter entries AFTER the last full tank entry's timestamp
          .where('createdAt', isGreaterThan: lastFullTankTimestamp)
          .orderBy('createdAt', descending: false)
          .get();

      double totalIntermediateVolume = 0.0;
      for (var doc in intermediateEntriesQuery.docs) {
        final volumeData = doc.data()['volume'];
        if (volumeData is num) {
          totalIntermediateVolume += volumeData.toDouble();
        }
      }

      return {
        // This is the mileage of the STARTING full tank (FT1)
        'lastFullTankMileage': lastFullTankMileage,
        // This is the sum of volumes of entries BETWEEN FT1 and the current fill (FT2)
        'totalVolumeSinceLastFullTank': totalIntermediateVolume,
      };
    } catch (e) {
      print("❌ Error getting fuel summary: $e");
      return {
        'lastFullTankMileage': 0,
        'lastFullTankTimestamp': null,
        'totalVolumeSinceLastFullTank': 0.0,
      };
    }
  }

  /// ----------------------------------------
  /// 🟢 NEW FUNCTION: Get Historical Average Fuel Efficiency (km/L)
  ///
  /// Calculates the average fuel efficiency from all past full tank entries
  /// where fuel efficiency was successfully calculated (FE > 0).
  /// ----------------------------------------
  Future<double> getAverageFuelEfficiency(String vehicleId) async {
    try {
      // 1. Query all FULL TANK entries for the vehicle
      final fullTankEntries = await _firestore
          .collection('FuelEntry')
          .where('vehicleId', isEqualTo: vehicleId)
          .where('isFullTank', isEqualTo: true)
          // We only care about entries that successfully calculated an FE > 0
          .where('fuelEfficiency', isGreaterThan: 0)
          .get();

      if (fullTankEntries.docs.isEmpty) {
        return 0.0;
      }

      double totalEfficiency = 0.0;
      int validCount = 0;

      for (var doc in fullTankEntries.docs) {
        final data = doc.data();
        final fe = data['fuelEfficiency'];

        // Ensure 'fuelEfficiency' is a number
        if (fe is num) {
          totalEfficiency += fe.toDouble();
          validCount++;
        }
      }

      if (validCount == 0) {
        return 0.0;
      }

      // 2. Calculate average
      return totalEfficiency / validCount;
    } catch (e) {
      print("❌ Error getting average fuel efficiency: $e");
      return 0.0;
    }
  }

  /// -----------------------------
  /// 🔵 Add New Fuel Entry (Mileage accepts int)
  /// -----------------------------
  Future<void> addFuelEntry({
    required String uid,
    required String vehicleId,
    required double amount,
    required double volumeL,
    required double pricePerLiter,
    required String fuelType,
    required String station,
    required int mileage, // <--- Accepts INT
    required String date, // yyyy-MM-dd
    required bool isFullTank,
    String? imgURL,
    required double fuelEfficiency,
  }) async {
    try {
      await _firestore.collection('FuelEntry').add({
        'uid': uid,
        'vehicleId': vehicleId,
        'category': 'fuel',
        'amount': amount,
        'volume': volumeL,
        'pricePerLiter': pricePerLiter,
        'fuelType': fuelType,
        'station': station,
        'mileage': mileage, // <--- Saves as INT
        'date': date,
        'isFullTank': isFullTank,
        'imageUrl': imgURL ?? '',
        'fuelEfficiency': fuelEfficiency,
        'createdAt': FieldValue.serverTimestamp(),
      });

      print("✅ Fuel entry added successfully to FuelEntry.");
    } catch (e) {
      print("❌ Error adding fuel entry: $e");
      rethrow;
    }
  }

  /// -----------------------------
  /// 🔵 STREAM FUEL ENTRIES
  /// -----------------------------
  Stream<List<Map<String, dynamic>>> getFuelEntries({
    required String uid,
    String? vehicleId,
    DateTimeRange? dateRange,
    String sortBy = 'date', // 'date' or 'amount'
  }) {
    // 1. Define the base query for the FuelEntry root collection, filtering by UID
    Query query = _firestore
        .collection('FuelEntry')
        .where(
          'uid',
          isEqualTo: uid,
        ); // Filter to only show the current user's entries

    // The document's date is stored in 'createdAt' (Timestamp) and 'date' (String yyyy-MM-dd)
    // We must use the Timestamp field ('createdAt') for range filtering and proper sorting.

    // 2. Apply Vehicle Filter
    if (vehicleId != null) {
      query = query.where('vehicleId', isEqualTo: vehicleId);
    }

    // 3. Apply Date Range Filter (using the 'createdAt' Timestamp field)
    if (dateRange != null) {
      query = query.where('createdAt', isGreaterThanOrEqualTo: dateRange.start);
      // ... and isLessThanOrEqualTo: end
    }

    // 4. Apply Sorting
    String sortField = sortBy == 'amount' ? 'amount' : 'createdAt';
    query = query.orderBy(sortField, descending: true);

    // 5. Stream the results
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id; // Include the document ID

        // If the date field is missing (old data), format the 'createdAt' timestamp
        if (!data.containsKey('date') || data['date'] == null) {
          if (data.containsKey('createdAt') && data['createdAt'] is Timestamp) {
            data['date'] = DateFormat(
              'MMM dd, yyyy',
            ).format(data['createdAt'].toDate());
          } else {
            data['date'] = 'N/A';
          }
        }

        return data;
      }).toList();
    });
  }

  /// ----------------------------------------
  /// 🔵 Convert DateTime to yyyy-MM-dd
  /// ----------------------------------------
  String formatDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }
}
