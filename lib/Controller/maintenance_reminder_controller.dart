import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ridefix/Services/notification_service.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';

class MaintenanceReminderController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionName = 'MaintenanceReminder';
  final NotificationService _notificationService = NotificationService();

  Future<void> addReminder(MaintenanceReminderModel reminder) async {
    try {
      // Add reminder to Firestore
      DocumentReference docRef = await _firestore
          .collection(_collectionName)
          .add(reminder.toMap());

      // Schedule notification
      DateTime scheduledTime = _parseDateTime(
        reminder.dateExpired,
        reminder.timeExpired,
      );

      await _notificationService.scheduleNotification(
        id: docRef.id.hashCode,
        title: 'Maintenance Reminder',
        body: '${reminder.maintenanceType} is due now!',
        scheduledTime: scheduledTime,
      );

      print('Reminder added with notification scheduled');
    } catch (e) {
      print('Error adding reminder: $e');
      rethrow;
    }
  }

  Stream<List<MaintenanceReminderModel>> getUserReminders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: user.uid)
        .orderBy('dateExpired', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MaintenanceReminderModel.fromMap(doc.data(), doc.id),
              )
              .toList(),
        );
  }

  Future<void> updateReminder(String id, Map<String, dynamic> data) async {
    try {
      // Check if reminder exists and is not expired
      final docSnapshot = await _firestore
          .collection(_collectionName)
          .doc(id)
          .get();

      if (!docSnapshot.exists) {
        throw Exception('Reminder not found');
      }

      final currentData = docSnapshot.data()!;

      // Prevent editing expired reminders
      if (currentData['status'] == 'expired') {
        throw Exception('Cannot edit expired reminders');
      }

      // Update in Firestore
      await _firestore.collection(_collectionName).doc(id).update(data);

      // Cancel old notification
      await _notificationService.cancelNotification(id.hashCode);

      // Schedule new notification if date/time provided
      if (data.containsKey('dateExpired') && data.containsKey('timeExpired')) {
        DateTime scheduledTime = _parseDateTime(
          data['dateExpired'],
          data['timeExpired'],
        );

        // Verify the new time is not in the past
        if (scheduledTime.isBefore(DateTime.now())) {
          throw Exception('Cannot schedule reminder for past date/time');
        }

        String maintenanceType = data['maintenanceType'] ?? 'Maintenance';

        await _notificationService.scheduleNotification(
          id: id.hashCode,
          title: 'Maintenance Reminder',
          body: '$maintenanceType is due now!',
          scheduledTime: scheduledTime,
        );
      }

      print('Reminder updated with notification rescheduled');
    } catch (e) {
      print('Error updating reminder: $e');
      rethrow;
    }
  }

  Future<void> deleteReminder(String id) async {
    try {
      // Cancel notification
      await _notificationService.cancelNotification(id.hashCode);

      // Delete from Firestore
      await _firestore.collection(_collectionName).doc(id).delete();

      print('Reminder and notification deleted');
    } catch (e) {
      print('Error deleting reminder: $e');
      rethrow;
    }
  }

  /// Mark a reminder as expired
  Future<void> _markAsExpired(String id) async {
    try {
      await _firestore.collection(_collectionName).doc(id).update({
        'status': 'expired',
        'expiredAt': FieldValue.serverTimestamp(), // Track when it expired
      });

      // Cancel notification for expired reminder
      await _notificationService.cancelNotification(id.hashCode);

      print('Reminder $id marked as expired');
    } catch (e) {
      print('Error marking reminder as expired: $e');
    }
  }

  /// Check and update expired reminders in batch - Call this on app startup
  Future<void> checkAndUpdateExpiredReminders() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      final now = DateTime.now();

      final snapshot = await _firestore
          .collection(_collectionName)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      final batch = _firestore.batch();
      int expiredCount = 0;

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final reminderDateTime = _parseDateTime(
            data['dateExpired'],
            data['timeExpired'],
          );

          // If reminder is expired, update its status in batch
          if (reminderDateTime.isBefore(now)) {
            batch.update(doc.reference, {
              'status': 'expired',
              'expiredAt': FieldValue.serverTimestamp(),
            });

            // Cancel notification
            await _notificationService.cancelNotification(doc.id.hashCode);
            expiredCount++;
          }
        } catch (e) {
          print('Error checking reminder ${doc.id}: $e');
        }
      }

      if (expiredCount > 0) {
        await batch.commit();
        print('Marked $expiredCount reminders as expired');
      }
    } catch (e) {
      print('Error checking expired reminders: $e');
    }
  }

  /// Get active reminders - properly filtered
  Stream<List<MaintenanceReminderModel>> getActiveReminders() {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .orderBy('dateExpired')
        .snapshots()
        .asyncMap((snapshot) async {
          final now = DateTime.now();
          final activeReminders = <MaintenanceReminderModel>[];
          final expiredIds = <String>[];

          // First pass: categorize reminders
          for (var doc in snapshot.docs) {
            try {
              final reminder = MaintenanceReminderModel.fromMap(
                doc.data(),
                doc.id,
              );
              final reminderDateTime = _parseDateTime(
                reminder.dateExpired,
                reminder.timeExpired,
              );

              if (reminderDateTime.isBefore(now)) {
                expiredIds.add(doc.id);
                print(
                  '⏰ Found expired: ${reminder.maintenanceType} - Was due: $reminderDateTime',
                );
              } else {
                activeReminders.add(reminder);
                print(
                  '✅ Active: ${reminder.maintenanceType} - Due: $reminderDateTime',
                );
              }
            } catch (e) {
              print('❌ Error parsing reminder ${doc.id}: $e');
            }
          }

          // Batch update expired reminders
          if (expiredIds.isNotEmpty) {
            final batch = _firestore.batch();
            for (var id in expiredIds) {
              batch.update(_firestore.collection(_collectionName).doc(id), {
                'status': 'expired',
                'expiredAt': FieldValue.serverTimestamp(),
              });
              // Cancel notifications
              _notificationService.cancelNotification(id.hashCode);
            }
            await batch.commit();
            print('Batch updated ${expiredIds.length} expired reminders');
          }

          print('📋 Total active reminders: ${activeReminders.length}');
          return activeReminders;
        });
  }

  /// Get expired reminders
  Stream<List<MaintenanceReminderModel>> getExpiredReminders() {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return _firestore
        .collection(_collectionName)
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'expired')
        .orderBy('dateExpired', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => MaintenanceReminderModel.fromMap(doc.data(), doc.id),
              )
              .toList(),
        );
  }

  /// Confirm delete helper with notification cancellation
  Future<bool> confirmAndDeleteReminder(BuildContext context, String id) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Reminder"),
        content: const Text("Are you sure you want to delete this reminder?"),
        actions: [
          TextButton(
            style: ElevatedButton.styleFrom(foregroundColor: Colors.black),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );

    if (result == true) {
      await deleteReminder(id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reminder deleted successfully.')),
        );
      }
      return true;
    }
    return false;
  }

  /// Parse date and time strings into DateTime object
  DateTime _parseDateTime(String date, String time) {
    DateTime dateTime = DateTime.parse(date);

    // Parse time (handle AM/PM format)
    TimeOfDay timeOfDay;
    if (time.contains('AM') || time.contains('PM')) {
      final isPM = time.contains('PM');
      final timeWithoutPeriod = time.replaceAll(RegExp(r'[AP]M'), '').trim();
      final parts = timeWithoutPeriod.split(':');
      int hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }

      timeOfDay = TimeOfDay(hour: hour, minute: minute);
    } else {
      final parts = time.split(':');
      timeOfDay = TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    return DateTime(
      dateTime.year,
      dateTime.month,
      dateTime.day,
      timeOfDay.hour,
      timeOfDay.minute,
    );
  }
}
