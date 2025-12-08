import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceReminderModel {
  final String? id;
  final String userId;
  final String maintenanceType;
  final DateTime dueDateTime;
  final DateTime createdAt;
  final String status;
  final String? vehicleId; // <-- 1. NEW FIELD to store the selected vehicle ID

  MaintenanceReminderModel({
    this.id,
    required this.userId,
    required this.maintenanceType,
    required this.dueDateTime,
    required this.createdAt,
    this.status = 'active',
    this.vehicleId, // <-- 2. Added to constructor
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'maintenanceType': maintenanceType,
      'dueDateTime': Timestamp.fromDate(dueDateTime),
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
      'vehicleId': vehicleId, // <-- 3. Added to the map for saving to Firestore
    };
  }

  factory MaintenanceReminderModel.fromMap(String id, Map<String, dynamic> map) {
    return MaintenanceReminderModel(
      id: id,
      userId: map['userId'] ?? '',
      maintenanceType: map['maintenanceType'] ?? '',
      dueDateTime: (map['dueDateTime'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'active',
      vehicleId: map['vehicleId'], // <-- 4. Added for reading from Firestore
    );
  }
}
