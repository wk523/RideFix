import 'package:cloud_firestore/cloud_firestore.dart';

/// VEHICLE MODEL
class Vehicle {
  final String vehicleId;
  final String brand;
  final String color;
  final String model;
  final String plateNumber;
  final int manYear;
  final String uid;
  final String roadTaxExpired;
  final int mileage;
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

  Vehicle copyWith({
    String? vehicleId,
    String? brand,
    String? color,
    String? model,
    String? plateNumber,
    int? manYear,
    String? uid,
    String? roadTaxExpired,
    int? mileage,
    String? imageUrl,
  }) {
    return Vehicle(
      vehicleId: vehicleId ?? this.vehicleId,
      brand: brand ?? this.brand,
      color: color ?? this.color,
      model: model ?? this.model,
      plateNumber: plateNumber ?? this.plateNumber,
      manYear: manYear ?? this.manYear,
      uid: uid ?? this.uid,
      roadTaxExpired: roadTaxExpired ?? this.roadTaxExpired,
      mileage: mileage ?? this.mileage,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    int safeParseInt(dynamic value, {int defaultValue = 0}) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    return Vehicle(
      vehicleId: data['Vehicleid'] ?? doc.id,
      brand: data['Brand'] ?? '',
      color: data['Color'] ?? '',
      model: data['Model'] ?? '',
      plateNumber: data['Platenumber'] ?? '',
      manYear: safeParseInt(data['Manyear']),
      uid: data['uid'] ?? '',
      roadTaxExpired: data['Roadtaxexpired'] ?? '',
      mileage: safeParseInt(data['mileage']),
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