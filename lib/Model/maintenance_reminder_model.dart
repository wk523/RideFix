import 'package:cloud_firestore/cloud_firestore.dart';

class MaintenanceReminderModel {
  final String id;
  final String userId;
  final String maintenanceType;
  final String dateExpired;
  final String timeExpired;
  final String status;

  MaintenanceReminderModel({
    required this.id,
    required this.userId,
    required this.maintenanceType,
    required this.dateExpired,
    required this.timeExpired,
    this.status = 'active',
  });

  /// ✅ Correct Firestore map
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'maintenanceType': maintenanceType,
      'dateExpired': dateExpired,
      'timeExpired': timeExpired,
      'status': status.isNotEmpty ? status : 'active',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// ✅ For reading from Firestore
  factory MaintenanceReminderModel.fromMap(Map<String, dynamic> data, String id) {
    return MaintenanceReminderModel(
      id: id,
      userId: data['userId'] ?? '',
      maintenanceType: data['maintenanceType'] ?? '',
      dateExpired: data['dateExpired'] ?? '',
      timeExpired: data['timeExpired'] ?? '',
      status: data['status'] ?? 'active',
    );
  }
}
