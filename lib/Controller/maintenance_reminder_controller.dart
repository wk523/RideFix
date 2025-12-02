import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';
import 'package:ridefix/services/notification_service.dart';

class MaintenanceReminderController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = "MaintenanceReminder";
  final NotificationService _notificationService = NotificationService();

  Future<void> addReminder(MaintenanceReminderModel model) async {
    final docRef = _firestore.collection(_collection).doc();
    await docRef.set(model.toMap());

    await _notificationService.scheduleNotification(
      id: docRef.id.hashCode,
      title: "Maintenance Reminder",
      body: "Your ${model.maintenanceType} is due soon.",
      scheduledTime: model.dueDateTime,
      category: model.maintenanceType, // ✅ 添加 category 参数
      reminderId: docRef.id,
    );
  }

  Future<void> updateReminder(String id, MaintenanceReminderModel model) async {
    // 🔥 自动检查是否 expired
    String updatedStatus =
    model.dueDateTime.isBefore(DateTime.now()) ? "expired" : model.status;

    await _firestore.collection(_collection).doc(id).update({
      "maintenanceType": model.maintenanceType,
      "dueDateTime": Timestamp.fromDate(model.dueDateTime),
      "status": updatedStatus, // 🔥 自动更新 status
      "createdAt": Timestamp.fromDate(model.createdAt),
    });

    // 🔥 取消旧通知
    await _notificationService.cancelNotification(id.hashCode);

    // 🔥 expired 就不要再创建新通知
    if (updatedStatus != "expired") {
      await _notificationService.scheduleNotification(
        id: id.hashCode,
        title: "Updated Reminder",
        body: "Your ${model.maintenanceType} reminder has been updated.",
        scheduledTime: model.dueDateTime,
        category: model.maintenanceType,
        reminderId: id,
      );
    }
  }


  /// 🔥 DELETE REMINDER
  Future<void> deleteReminder(String reminderId) async {
    await _firestore.collection(_collection).doc(reminderId).delete();
    await _notificationService.cancelNotification(reminderId.hashCode);
  }

  /// 🔥 Confirm + Delete (Handled in controller)
  Future<bool> confirmAndDeleteReminder(BuildContext context, String reminderId) async {
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
      await deleteReminder(reminderId);
      return true;
    }
    return false;
  }

  /// 🔥 GET ALL USER REMINDERS
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

  /// 🔥 GET ONLY ACTIVE REMINDERS
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