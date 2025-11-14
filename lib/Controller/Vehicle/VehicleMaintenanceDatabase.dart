import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
// import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// VEHICLE MODEL
class Vehicle {
  final String vehicleId;
  final String brand;
  final String color;
  final String model;
  final String plateNumber;
  final String manYear;
  final String uid;
  final String roadTaxExpired;
  final String mileage;
  final String imageUrl;

  Vehicle({
    required this.vehicleId,
    required this.brand,
    required this.color,
    required this.model,
    required this.plateNumber,
    required this.manYear,
    required this.uid,
    required this.roadTaxExpired,
    required this.mileage,
    required this.imageUrl,
  });

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      vehicleId: data['Vehicleid'] ?? doc.id, // ✅ fallback to doc.id
      brand: data['Brand'] ?? '',
      color: data['Color'] ?? '',
      model: data['Model'] ?? '',
      plateNumber: data['Platenumber'] ?? '',
      manYear: data['Manyear'] ?? '',
      uid: data['uid'] ?? '',
      roadTaxExpired: data['Roadtaxexpired']?.toString() ?? '',
      mileage: data['mileage']?.toString() ?? '0',
      imageUrl: data['imageUrl'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Vehicleid': vehicleId,
      'Brand': brand,
      'Color': color,
      'Model': model,
      'Platenumber': plateNumber,
      'Manyear': manYear,
      'uid': uid,
      'Roadtaxexpired': roadTaxExpired,
      'mileage': mileage,
      'imageUrl': imageUrl,
    };
  }
}

/// VEHICLE DATA SERVICE
class VehicleDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // -------------------------
  // Validation
  // -------------------------
  String? validateVehicleData(Vehicle vehicle) {
    final platePattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9]+$');
    if (!platePattern.hasMatch(vehicle.plateNumber)) {
      return 'Plate number must include at least one letter and one number.';
    }

    final colorPattern = RegExp(r'^[A-Za-z]+$');
    if (!colorPattern.hasMatch(vehicle.color)) {
      return 'Color must contain only alphabets.';
    }

    final yearPattern = RegExp(r'^\d{4}$');
    if (!yearPattern.hasMatch(vehicle.manYear)) {
      return 'Manufacture Year must be 4 digits.';
    }
    final year = int.tryParse(vehicle.manYear) ?? 0;
    if (year < 1900 || year > DateTime.now().year + 1) {
      return 'Manufacture Year must be between 1900 and ${DateTime.now().year + 1}.';
    }

    final mileagePattern = RegExp(r'^\d+$');
    if (!mileagePattern.hasMatch(vehicle.mileage)) {
      return 'Mileage must contain only numbers.';
    }

    return null;
  }

  // -------------------------
  // Pick image (no upload)
  // -------------------------
  /// Opens image picker and returns the raw bytes (or null if cancelled).
  /// This function DOES NOT upload — it only returns the bytes so UI can preview.
  Future<Uint8List?> pickImage() async {
    final ImagePicker picker = ImagePicker();

    // Pick single image from gallery
    final XFile? picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final Uint8List bytes = await picked.readAsBytes();
    return bytes;
  }

  // -------------------------
  // Upload image from bytes (called on Register)
  // -------------------------
  /// Uploads given bytes to Firebase storage with a filename generated from plateNumber.
  /// Returns public URL or null on failure.
  Future<String?> uploadImageFromBytes(
    Uint8List bytes,
    String plateNumber,
  ) async {
    // Use FirebaseStorage.instance to interact with the service.
    final FirebaseStorage storage = FirebaseStorage.instance;

    try {
      // 1. Prepare Filename
      final normalizedPlate = (plateNumber.trim().isEmpty)
          ? 'UNKNOWN'
          : plateNumber.trim().toUpperCase();
      final fileName =
          '$normalizedPlate-${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 2. Define Storage Reference (Path/Location)
      // This creates a reference pointing to: /vehicle_images/fileName.jpg
      final storageRef = storage.ref().child('vehicle_images').child(fileName);

      // 3. Upload the Bytes (using putData)
      // The content type is automatically inferred or can be explicitly set via SettableMetadata
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // 4. Wait for the upload to complete
      final snapshot = await uploadTask;

      // 5. Get the Public Download URL
      final publicUrl = await snapshot.ref.getDownloadURL();

      print("✅ Image uploaded to Firebase Storage. URL: $publicUrl");
      return publicUrl;
    } on FirebaseException catch (e) {
      // Handle Firebase-specific errors (e.g., permission denied)
      print('❌ Firebase Storage upload failed: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      // Catch other general errors
      print('❌ General upload failed: $e');
      return null;
    }
  }

  // -------------------------
  // Update Vehicle Mileage
  // -------------------------
  Future<void> updateVehicleMileage(String vehicleId, double newMileage) async {
    await _firestore.collection('Vehicle').doc(vehicleId).update({
      'mileage': newMileage,
    });
  }

  // -------------------------
  // Register vehicle in Firestore
  // -------------------------
  Future<void> registerVehicle(Vehicle vehicle) async {
    try {
      final vehicleId = vehicle.vehicleId.isEmpty
          ? _firestore
                .collection('Vehicle')
                .doc()
                .id // ✅ auto-generate ID
          : vehicle.vehicleId;

      final newVehicle = Vehicle(
        vehicleId: vehicleId,
        brand: vehicle.brand.trim().toUpperCase(),
        color: vehicle.color.trim().toUpperCase(),
        model: vehicle.model.trim().toUpperCase(),
        plateNumber: vehicle.plateNumber.trim().toUpperCase(),
        manYear: vehicle.manYear.trim(),
        uid: vehicle.uid,
        roadTaxExpired: vehicle.roadTaxExpired.trim(),
        mileage: vehicle.mileage.trim(),
        imageUrl: vehicle.imageUrl,
      );

      final error = validateVehicleData(newVehicle);
      if (error != null) throw Exception(error);

      await _firestore
          .collection('Vehicle')
          .doc(vehicleId)
          .set(newVehicle.toMap());
      print('✅ Vehicle registered (Firestore).');
    } catch (e) {
      print('❌ Error registering vehicle: $e');
      rethrow;
    }
  }

  // -------------------------
  // Read & Stream helpers
  // -------------------------
  Future<List<Vehicle>> readVehicleData() async {
    final qs = await _firestore.collection('Vehicle').get();
    return qs.docs.map((d) => Vehicle.fromFirestore(d)).toList();
  }

  Stream<List<Vehicle>> get vehiclesStream {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return _firestore
        .collection('Vehicle')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) => Vehicle.fromFirestore(d)).toList();
        });
  }

  /// Uploads raw image bytes to Firebase Storage under the 'vehicle_images' path
  /// and returns the public download URL.
  Future<String?> uploadVehicleImageFromBytes(
    Uint8List bytes,
    String plateNumber,
  ) async {
    // Use FirebaseStorage.instance to interact with the service.
    final FirebaseStorage storage = FirebaseStorage.instance;

    try {
      // 1. Prepare Filename
      final normalizedPlate = (plateNumber.trim().isEmpty)
          ? 'UNKNOWN'
          : plateNumber.trim().toUpperCase();

      // Note: Using hyphen separator for consistency with the previous Firebase version.
      final fileName =
          '$normalizedPlate-${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 2. Define Storage Reference (Path/Location)
      // This creates a reference pointing to: /vehicle_images/fileName.jpg
      final storageRef = storage.ref().child('vehicle_images').child(fileName);

      // 3. Upload the Bytes (using putData)
      final uploadTask = storageRef.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // 4. Wait for the upload to complete
      final snapshot = await uploadTask;

      // 5. Get the Public Download URL
      final publicUrl = await snapshot.ref.getDownloadURL();

      print("✅ Image uploaded to Firebase Storage. URL: $publicUrl");
      return publicUrl;
    } on FirebaseException catch (e) {
      // Handle Firebase-specific errors (e.g., permission denied)
      print('❌ Firebase Storage upload failed: ${e.code} - ${e.message}');
      return null;
    } catch (e) {
      // Catch other general errors
      print('❌ General upload failed: $e');
      return null;
    }
  }

  // -------------------------
  // Delete old image from Firebase Storage
  // -------------------------

  /// Deletes an image from Firebase Storage using its public URL.
  Future<void> deleteVehicleImage(String? url) async {
    if (url == null || url.isEmpty) return;

    try {
      // Firebase Storage provides refFromURL to easily get the reference
      // regardless of the complex URL structure.
      final Reference storageRef = FirebaseStorage.instance.refFromURL(url);

      await storageRef.delete();

      print(
        '🗑️ Deleted old image from Firebase Storage: ${storageRef.fullPath}',
      );
    } on FirebaseException catch (e) {
      // If the file is not found (e.g., deleted by another client), we can safely
      // handle the exception and stop here.
      if (e.code == 'object-not-found') {
        print(
          '⚠️ Image file not found at URL (already deleted or wrong path): $url',
        );
      } else {
        // Re-throw other critical exceptions
        print(
          '⚠️ Failed to delete old image from Firebase: ${e.code} - ${e.message}',
        );
        rethrow;
      }
    } catch (e) {
      print('⚠️ General failure during image deletion: $e');
      rethrow;
    }
  }

  // -------------------------
  // Update Vehicle (with optional new image)
  // -------------------------
  Future<String?> updateVehicle(
    Vehicle updatedVehicle, {
    Uint8List? newImageBytes,
  }) async {
    try {
      if (updatedVehicle.vehicleId.isEmpty) {
        throw Exception("Vehicle ID is missing");
      }

      String finalImageUrl = updatedVehicle.imageUrl;

      // ✅ Upload new image (and delete old one)
      if (newImageBytes != null) {
        if (updatedVehicle.imageUrl.isNotEmpty) {
          await deleteVehicleImage(updatedVehicle.imageUrl);
        }

        final uploadedUrl = await uploadVehicleImageFromBytes(
          newImageBytes,
          updatedVehicle.plateNumber,
        );

        if (uploadedUrl != null) {
          finalImageUrl = uploadedUrl;
        } else {
          throw Exception("Image upload failed");
        }
      }

      // ✅ Update Firestore with final image URL
      final updatedMap = updatedVehicle.toMap()..['imageUrl'] = finalImageUrl;

      final error = validateVehicleData(updatedVehicle);
      if (error != null) throw Exception(error);

      await _firestore
          .collection('Vehicle')
          .doc(updatedVehicle.vehicleId)
          .update(updatedMap);

      print('✅ Vehicle updated successfully in Firestore.');
      return finalImageUrl; // ✅ return new URL so UI can refresh preview
    } catch (e) {
      print('❌ Error updating vehicle: $e');
      rethrow;
    }
  }

  // -------------------------
  // Delete Vehicle (Firestore + Image)
  // -------------------------
  Future<void> deleteVehicle(BuildContext context, Vehicle vehicle) async {
    try {
      // ✅ Confirm before deletion
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text(
              'Confirm Deletion',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            content: Text(
              'Are you sure you want to delete this vehicle?\n\n'
              'Brand: ${vehicle.brand}\n'
              'Model: ${vehicle.model}\n'
              'Plate Number: ${vehicle.plateNumber}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirm != true) return; // user cancelled ❌

      // ✅ Delete Firestore doc
      await FirebaseFirestore.instance
          .collection('Vehicle')
          .doc(vehicle.vehicleId)
          .delete();

      // ✅ Delete from Firebase (if image exists)
      await vehicleDataService.deleteVehicleImage(vehicle.imageUrl);

      // ✅ Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vehicle deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // Go back after deletion
      }

      print('🗑️ Vehicle deleted successfully: ${vehicle.vehicleId}');
    } catch (e) {
      print('❌ Error deleting vehicle: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting vehicle: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

final vehicleDataService = VehicleDataService();

extension VehicleRegisterExtension on VehicleDataService {
  Future<void> registerVehicle(Vehicle vehicle) async {
    try {
      await _firestore
          .collection('Vehicle')
          .doc(vehicle.vehicleId)
          .set(vehicle.toMap());
    } catch (e) {
      throw Exception('Failed to register vehicle: $e');
    }
  }
}
