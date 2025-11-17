import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return; // prevent multiple init calls

    // Initialize timezones
    tzData.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // iOS permission
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Android 13+ permission
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    _initialized = true;
    print('✅ NotificationService initialized successfully.');
  }

  // Handle notification tap
  void _onNotificationTapped(NotificationResponse response) async {
    print('🔔 Notification tapped: ${response.payload}');

    if (response.payload != null) {
      try {
        final reminderId = response.payload!;
        await _markReminderAsExpired(reminderId);
        print('Reminder $reminderId marked as expired after notification tap');
      } catch (e) {
        print('Error marking reminder as expired: $e');
      }
    }
  }

  Future<void> _markReminderAsExpired(String reminderId) async {
    try {
      await _firestore.collection('MaintenanceReminder').doc(reminderId).update(
        {'status': 'expired'},
      );
    } catch (e) {
      print('Error updating reminder status: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    String? reminderId,
  }) async {
    try {
      // ✅ Ensure notification system is initialized
      if (!_initialized) {
        await initialize();
      }

      final androidDetails = AndroidNotificationDetails(
        'maintenance_reminders',
        'Maintenance Reminders',
        channelDescription: 'Notifications for vehicle maintenance reminders',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);

      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduledTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // uiLocalNotificationDateInterpretation:
        //     UILocalNotificationDateInterpretation.absoluteTime,
        payload: reminderId,
      );

      if (reminderId != null) {
        final expireTime = scheduledTime.add(const Duration(minutes: 1));
        await _scheduleAutoExpire(id + 1000000, reminderId, expireTime);
      }

      print('✅ Notification scheduled for: $tzScheduledTime');
    } catch (e) {
      print('❌ Error scheduling notification: $e');
      rethrow;
    }
  }

  Future<void> _scheduleAutoExpire(
    int id,
    String reminderId,
    DateTime expireTime,
  ) async {
    try {
      final tzExpireTime = tz.TZDateTime.from(expireTime, tz.local);

      const androidDetails = AndroidNotificationDetails(
        'auto_expire',
        'Auto Expire',
        channelDescription: 'Background task to expire reminders',
        importance: Importance.low,
        priority: Priority.low,
        showWhen: false,
        playSound: false,
        enableVibration: false,
        visibility: NotificationVisibility.secret,
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: false,
        presentBadge: false,
        presentSound: false,
      );

      const notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        id,
        'Expire Reminder',
        'Background expire task',
        tzExpireTime,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        // uiLocalNotificationDateInterpretation:
        //     UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'expire:$reminderId',
      );

      Future.delayed(expireTime.difference(DateTime.now()), () {
        _markReminderAsExpired(reminderId);
      });

      print('🕒 Auto-expire scheduled for: $tzExpireTime');
    } catch (e) {
      print('Error scheduling auto-expire: $e');
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await _notificationsPlugin.cancel(id);
      await _notificationsPlugin.cancel(id + 1000000);
      print('🗑️ Notification cancelled: $id');
    } catch (e) {
      print('Error cancelling notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    try {
      await _notificationsPlugin.cancelAll();
      print('🧹 All notifications cancelled');
    } catch (e) {
      print('Error cancelling all notifications: $e');
    }
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}
