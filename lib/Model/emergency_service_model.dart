import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class ServicePlace {
  final String id;
  final String name;
  final String phone;
  final double rating;
  final int totalReviews;
  final double latitude;
  final double longitude;
  final double distanceKm; // Calculated distance from user

  ServicePlace({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
    required this.totalReviews,
    required this.latitude,
    required this.longitude,
    this.distanceKm = 0.0,
  });

  // Factory constructor for simulation or data parsing
  factory ServicePlace.fromMap(Map<String, dynamic> data) {
    return ServicePlace(
      id: data['id'] as String,
      name: data['name'] as String,
      phone: data['phone'] as String,
      rating: (data['rating'] as num).toDouble(),
      totalReviews: data['totalReviews'] as int,
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      distanceKm: (data['distanceKm'] as num? ?? 0.0).toDouble(),
    );
  }

  // Used by the controller to update the distance after calculation
  ServicePlace copyWith({required double distance}) {
    return ServicePlace(
      id: id,
      name: name,
      phone: phone,
      rating: rating,
      totalReviews: totalReviews,
      latitude: latitude,
      longitude: longitude,
      distanceKm: distance, // This is the key field update
    );
  }
}

class EmergencyContact {
  final String id;
  final String name;
  final String number;

  EmergencyContact({required this.id, required this.name, required this.number});

  factory EmergencyContact.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>?;
    return EmergencyContact(
      id: doc.id,
      name: data?['name'] ?? 'Unknown Contact',
      // Ensure the number is always a string from Firestore
      number: data?['number'] ?? 'N/A',
    );
  }
}

// Haversine formula to calculate distance between two coordinates in km
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0; // Earth radius in km
  final lat1Rad = lat1 * (pi / 180);
  final lon1Rad = lon1 * (pi / 180);
  final lat2Rad = lat2 * (pi / 180);
  final lon2Rad = lon2 * (pi / 180);

  final dLat = lat2Rad - lat1Rad;
  final dLon = lon2Rad - lon1Rad;

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c; // Distance in km
}
