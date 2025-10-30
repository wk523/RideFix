// lib/Controller/Vehicle/VehicleMaintenanceDatabase.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// VEHICLE MODEL
class Vehicle {
  final String vehicleId;
  final String brand;
  final String color;
  final String model;
  final String plateNumber;
  final String manYear;
  final String ownerId;
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
    required this.ownerId,
    required this.roadTaxExpired,
    required this.mileage,
    required this.imageUrl,
  });

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Vehicle(
      vehicleId: data['Vehicleid'] ?? '',
      brand: data['Brand'] ?? '',
      color: data['Color'] ?? '',
      model: data['Model'] ?? '',
      plateNumber: data['Platenumber'] ?? '',
      manYear: data['Manyear'] ?? '',
      ownerId: data['ownerid'] ?? '',
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
      'ownerid': ownerId,
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
  /// Uploads given bytes to Supabase storage with a filename generated from plateNumber.
  /// Returns public URL or null on failure.
  Future<String?> uploadImageFromBytes(
    Uint8List bytes,
    String plateNumber,
  ) async {
    try {
      final normalizedPlate = (plateNumber.trim().isEmpty)
          ? 'UNKNOWN'
          : plateNumber.trim().toUpperCase();
      final fileName =
          '$normalizedPlate${DateTime.now().millisecondsSinceEpoch}.jpg';

      // NOTE: make sure bucket 'vehicle_images' exists and your Supabase client (anon key or service key)
      // has permission to write. If you run into RLS/403, fix bucket policy in Supabase.
      final res = await Supabase.instance.client.storage
          .from('vehicle_images')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      // uploadBinary returns empty map on success in some SDK versions;
      // we ignore content and fetch public URL next.
      final publicUrl = Supabase.instance.client.storage
          .from('vehicle_images')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      // Log and bubble up
      print('❌ Upload failed: $e');
      return null;
    }
  }

  // -------------------------
  // Register vehicle in Firestore
  // -------------------------
  Future<void> registerVehicle(Vehicle vehicle) async {
    try {
      final upperVehicle = Vehicle(
        vehicleId: vehicle.vehicleId,
        brand: vehicle.brand.trim().toUpperCase(),
        color: vehicle.color.trim().toUpperCase(),
        model: vehicle.model.trim().toUpperCase(),
        plateNumber: vehicle.plateNumber.trim().toUpperCase(),
        manYear: vehicle.manYear.trim(),
        ownerId: vehicle.ownerId,
        roadTaxExpired: vehicle.roadTaxExpired.trim(),
        mileage: vehicle.mileage.trim(),
        imageUrl: vehicle.imageUrl,
      );

      final error = validateVehicleData(upperVehicle);
      if (error != null) throw Exception(error);

      await _firestore
          .collection('Vehicle')
          .doc(upperVehicle.vehicleId)
          .set(upperVehicle.toMap());
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
    return _firestore.collection('Vehicle').snapshots().map((snap) {
      return snap.docs.map((d) => Vehicle.fromFirestore(d)).toList();
    });
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
