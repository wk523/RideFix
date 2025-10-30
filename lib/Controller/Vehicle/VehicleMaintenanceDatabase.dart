import 'package:cloud_firestore/cloud_firestore.dart';

// --- Vehicle Model Class ---
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

  // Convert Firestore document → Vehicle object
  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Vehicle(
      vehicleId: data['Vehicleid'] ?? '',
      brand: data['Brand'] ?? '',
      color: data['Color'] ?? '',
      model: data['Model'] ?? '',
      plateNumber: data['Platenumber'] ?? '',
      manYear: data['Manyear'] ?? '',
      ownerId: data['ownerid'] ?? data['ownerreid'] ?? '',
      roadTaxExpired: data['Roadtaxexpired']?.toString() ?? '',
      mileage: data['mileage']?.toString() ?? '0',
      imageUrl: data['imageUrl'] ?? 'assets/car_placeholder.png',
    );
  }

  // Convert Vehicle object → Firestore Map
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

// --- Vehicle Data Service ---
class VehicleDataService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Initialize connection
  final Future<void> initializationComplete = FirebaseFirestore.instance
      .waitForPendingWrites();

  // --- (1) Validate all fields before saving ---
  String? validateVehicleData(Vehicle vehicle) {
    // 1️⃣ Vehicle Plate Number must include at least one alphabet and one number
    final platePattern = RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z0-9]+$');
    if (!platePattern.hasMatch(vehicle.plateNumber)) {
      return 'Vehicle Plate Number must contain both letters and numbers.';
    }

    // 2️⃣ Color must be only alphabets
    final colorPattern = RegExp(r'^[A-Za-z]+$');
    if (!colorPattern.hasMatch(vehicle.color)) {
      return 'Color must only contain alphabets.';
    }

    // 3️⃣ Manufacture year must be numeric and reasonable (e.g., 1900–2025)
    final yearPattern = RegExp(r'^\d{4}$');
    if (!yearPattern.hasMatch(vehicle.manYear)) {
      return 'Manufacture Year must be a 4-digit number.';
    }
    final year = int.tryParse(vehicle.manYear) ?? 0;
    if (year < 1900 || year > DateTime.now().year + 1) {
      return 'Manufacture Year must be between 1900 and ${DateTime.now().year + 1}.';
    }

    // 4️⃣ Mileage must be numeric
    final mileagePattern = RegExp(r'^\d+$');
    if (!mileagePattern.hasMatch(vehicle.mileage)) {
      return 'Mileage must only contain numbers.';
    }

    return null; // ✅ Passed all checks
  }

  // --- (2) Register a new vehicle into Firestore ---
  Future<void> registerVehicle(Vehicle vehicle) async {
    try {
      // Convert all relevant fields to uppercase and trim spaces
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

      // Run validation before saving
      final errorMessage = validateVehicleData(upperVehicle);
      if (errorMessage != null) {
        throw Exception(errorMessage);
      }

      await _firestore
          .collection('Vehicle')
          .doc(upperVehicle.vehicleId)
          .set(upperVehicle.toMap());

      print('✅ Vehicle registered successfully (auto-uppercase applied)!');
    } catch (e) {
      print('❌ Error registering vehicle: $e');
      rethrow;
    }
  }

  // --- (3) Read all vehicle data once ---
  Future<List<Vehicle>> readVehicleData() async {
    try {
      final querySnapshot = await _firestore.collection('Vehicle').get();
      return querySnapshot.docs
          .map((doc) => Vehicle.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('❌ Error reading vehicle data: $e');
      rethrow;
    }
  }

  // --- (4) Stream (real-time updates) ---
  Stream<List<Vehicle>> get vehiclesStream {
    return _firestore.collection('Vehicle').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Vehicle.fromFirestore(doc)).toList();
    });
  }
}

// Global instance for easy use in your UI
final vehicleDataService = VehicleDataService();
