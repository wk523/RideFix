import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';
import 'package:ridefix/services/notification_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

class MaintenanceReminderController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = "MaintenanceReminder";
  final NotificationService _notificationService = NotificationService();

  MaintenanceReminderController() {
    _initializeTimezones();
  }

  Future<void> _initializeTimezones() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));
  }

  DateTime _convertMalaysiaToUtc(DateTime malaysiaTime) {
    final location = tz.getLocation('Asia/Kuala_Lumpur');
    return tz.TZDateTime.from(malaysiaTime, location).toUtc();
  }

  Future<void> addReminder(MaintenanceReminderModel model) async {
    final docRef = _firestore.collection(_collection).doc();

    final utcDueTime = _convertMalaysiaToUtc(model.dueDateTime);
    final reminderWithUtc = MaintenanceReminderModel(
      userId: model.userId,
      vehicleId: model.vehicleId, // <-- Pass vehicleId
      maintenanceType: model.maintenanceType,
      dueDateTime: utcDueTime,
      createdAt: DateTime.now().toUtc(),
      status: model.status,
    );

    await docRef.set(reminderWithUtc.toMap());

    await _notificationService.scheduleNotification(
      id: docRef.id.hashCode,
      title: "Maintenance Reminder",
      body: "Your ${model.maintenanceType} is due soon.",
      scheduledTime: utcDueTime,
      category: model.maintenanceType,
      reminderId: docRef.id,
    );
  }

  Future<void> updateReminder(String id, MaintenanceReminderModel model) async {
    final utcDueTime = _convertMalaysiaToUtc(model.dueDateTime);

    String updatedStatus = utcDueTime.isBefore(DateTime.now().toUtc())
        ? "expired"
        : model.status;

    await _firestore.collection(_collection).doc(id).update({
      "maintenanceType": model.maintenanceType,
      "dueDateTime": Timestamp.fromDate(utcDueTime),
      "status": updatedStatus,
      "vehicleId": model.vehicleId, // <-- Add vehicleId to the update
    });

    await _notificationService.cancelNotification(id.hashCode);

    if (updatedStatus != "expired") {
      await _notificationService.scheduleNotification(
        id: id.hashCode,
        title: "Updated Reminder",
        body: "Your ${model.maintenanceType} reminder has been updated.",
        scheduledTime: utcDueTime,
        category: model.maintenanceType,
        reminderId: id,
      );
    }
  }

  Future<void> deleteReminder(String reminderId) async {
    await _firestore.collection(_collection).doc(reminderId).delete();
    await _notificationService.cancelNotification(reminderId.hashCode);
  }

  Future<bool> confirmAndDeleteReminder(
    BuildContext context,
    String reminderId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Confirm Delete"),
          content: const Text("Are you sure you want to delete this reminder?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Yes", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        await deleteReminder(reminderId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Reminder deleted successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting reminder: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return false;
      }
    }
    return false;
  }

  Stream<List<MaintenanceReminderModel>> getUserReminders() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection(_collection)
        .where("userId", isEqualTo: uid)
        .orderBy("dueDateTime")
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return MaintenanceReminderModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
          }).toList();
        });
  }

  Stream<List<MaintenanceReminderModel>> getActiveReminders() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Stream.empty();

    return _firestore
        .collection(_collection)
        .where("userId", isEqualTo: uid)
        .where("status", isEqualTo: "active")
        .orderBy("dueDateTime")
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return MaintenanceReminderModel.fromMap(
              doc.id,
              doc.data() as Map<String, dynamic>,
            );
          }).toList();
        });
  }
}
