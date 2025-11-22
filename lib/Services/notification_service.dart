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

  FirebaseFirestore? _firestore;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    _firestore ??= FirebaseFirestore.instance;
    tzData.initializeTimeZones();

    // ✅ 设置为马来西亚时区
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
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

    // ✅ iOS 权限请求
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // ✅ Android 13+ 权限请求
    final androidImpl = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      print('📱 Android notification permission: $granted');
    }

    _initialized = true;
    print('✅ NotificationService initialized successfully with Asia/Kuala_Lumpur timezone');
  }

  /// ✅ 处理通知交互
  void _onNotificationTapped(NotificationResponse response) async {
    print('🔔 Notification tapped: ${response.payload}');

    if (response.payload != null && response.payload!.isNotEmpty) {
      await _markReminderAsExpired(response.payload!);
    }
  }

  Future<void> _markReminderAsExpired(String reminderId) async {
    try {
      await _firestore
          ?.collection('MaintenanceReminder')
          .doc(reminderId)
          .update({'status': 'expired'});
      print('✅ Reminder $reminderId marked as expired in Firebase');
    } catch (e) {
      print('❌ Error updating reminder status: $e');
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledTime,
    required String category,
    String? reminderId,
  }) async {
    if (!_initialized) await initialize();

    final androidDetails = AndroidNotificationDetails(
      'maintenance_reminders',
      'Maintenance Reminders',
      channelDescription: 'Notifications for vehicle maintenance reminders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      visibility: NotificationVisibility.public,
      // 🔥 添加 actions 让用户可以标记为完成
      actions: reminderId != null ? [
        AndroidNotificationAction(
          'mark_done',
          '✅ Mark as Done',
          showsUserInterface: false,
        ),
      ] : null,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 🔥 关键修复：将 DateTime 转换为 TZDateTime，保持一致的时区处理
    final tzScheduledTime = tz.TZDateTime.from(scheduledTime, tz.local);
    final now = tz.TZDateTime.now(tz.local);

    print('🕐 Scheduling Notification:');
    print('   Category: $category');
    print('   Current time: $now');
    print('   Scheduled time (input): $scheduledTime');
    print('   Scheduled time (TZ): $tzScheduledTime');
    print('   Minutes until: ${tzScheduledTime.difference(now).inMinutes}');

    if (tzScheduledTime.isBefore(now)) {
      print('⚠️ Time is in the past, marking as expired immediately');
      if (reminderId != null) {
        await _markReminderAsExpired(reminderId);
      }
      return;
    }

    // ✅ 安排主通知（在 dueDateTime）
    await _notificationsPlugin.zonedSchedule(
      id,
      '⏰ $category Maintenance Due',
      'Your $category maintenance is due now!',
      tzScheduledTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      payload: reminderId,
    );

    print('✅ Notification scheduled successfully');
  }

  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
    print('🗑️ Notification $id cancelled.');
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    print('🗑️ All notifications cancelled.');
  }

  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _notificationsPlugin.pendingNotificationRequests();
  }
}