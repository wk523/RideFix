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

  // --- (1) Register a new vehicle ---
  Future<void> registerVehicle(Vehicle vehicle) async {
    try {
      await _firestore
          .collection('Vehicle')
          .doc(vehicle.vehicleId)
          .set(vehicle.toMap());
      print('✅ Vehicle registered successfully!');
    } catch (e) {
      print('❌ Error registering vehicle: $e');
      rethrow;
    }
  }

  // --- (2) Read all vehicle data ---
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

  // --- (3) Stream (real-time updates) ---
  Stream<List<Vehicle>> get vehiclesStream {
    return _firestore.collection('Vehicle').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Vehicle.fromFirestore(doc)).toList();
    });
  }
}

// Global instance for easy use in your UI
final vehicleDataService = VehicleDataService();
