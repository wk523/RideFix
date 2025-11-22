import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceReminderModel {
  final String id;
  final String userId;
  final String maintenanceType;
  final DateTime dueDateTime;
  final DateTime createdAt;
  final String status;

  MaintenanceReminderModel({
    this.id = '', // Document ID (optional for creation)
    required this.userId,
    required this.maintenanceType,
    required this.dueDateTime,
    required this.createdAt,
    required this.status,
  });

  /// Convert model to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'maintenanceType': maintenanceType,
      'dueDateTime': Timestamp.fromDate(dueDateTime), // Stored in UTC
      'createdAt': Timestamp.fromDate(createdAt),     // Stored in UTC
      'status': status,
    };
  }

  /// Create model instance from Firestore data
  factory MaintenanceReminderModel.fromMap(String id, Map<String, dynamic> map) {
    return MaintenanceReminderModel(
      id: id, // Firestore document ID
      userId: map['userId'],
      maintenanceType: map['maintenanceType'],
      dueDateTime: (map['dueDateTime'] as Timestamp).toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      status: map['status'] ?? 'active',
    );
  }
}
