import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../model/parking_model.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzData;

class ParkingController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// 🔔 Local Notification Plugin
  final FlutterLocalNotificationsPlugin notifications =
  FlutterLocalNotificationsPlugin();

  GoogleMapController? _mapController;
  GoogleMapController? get mapController => _mapController;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  ParkingController() {
    _initNotifications(); // 初始化通知和时区
  }

  /// ----------------------------------------------------------
  /// 🔔 Initialize Notification + Malaysia Timezone
  /// ----------------------------------------------------------
  Future<void> _initNotifications() async {
    tzData.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Kuala_Lumpur'));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await notifications.initialize(settings);
  }

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    notifyListeners();
  }

  void moveCamera(LatLng position, {double zoom = 18.0}) {
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: position, zoom: zoom),
      ),
    );
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// ----------------------------------------------------------
  /// Firestore collection: parking_locations
  /// ----------------------------------------------------------
  CollectionReference<Map<String, dynamic>> _parkingCollection() {
    return _firestore.collection('parking_locations');
  }

  /// Convert Malaysia wall-clock components → UTC
  DateTime _convertMalaysiaComponentsToUtc(DateTime malaysiaLocalComponents) {
    final loc = tz.getLocation('Asia/Kuala_Lumpur');
    final tzDt = tz.TZDateTime(
      loc,
      malaysiaLocalComponents.year,
      malaysiaLocalComponents.month,
      malaysiaLocalComponents.day,
      malaysiaLocalComponents.hour,
      malaysiaLocalComponents.minute,
    );
    return tzDt.toUtc();
  }

  bool isValidFutureTimeMalaysia(DateTime malaysiaSelected) {
    final nowMalaysia = tz.TZDateTime.now(tz.getLocation('Asia/Kuala_Lumpur'));
    final selectedTz = tz.TZDateTime(
      tz.getLocation('Asia/Kuala_Lumpur'),
      malaysiaSelected.year,
      malaysiaSelected.month,
      malaysiaSelected.day,
      malaysiaSelected.hour,
      malaysiaSelected.minute,
    );
    return selectedTz.isAfter(nowMalaysia);
  }

  Parking createParkingFromForm({
    required String floor,
    required String lot,
    required double latitude,
    required double longitude,
    required DateTime malaysiaExpired,
  }) {
    final utc = _convertMalaysiaComponentsToUtc(malaysiaExpired);

    return Parking(
      parkingFloor: floor,
      lotNum: lot,
      latitude: latitude,
      longitude: longitude,
      expiredTimeUtc: utc,
    );
  }

  /// ----------------------------------------------------------
  /// Auto expire parkings whose expiredTimeUtc passed
  /// ----------------------------------------------------------
  Future<void> _autoExpireParkings() async {
    try {
      final nowUtc = DateTime.now().toUtc();
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final querySnapshot = await _parkingCollection()
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in querySnapshot.docs) {
        final parking = Parking.fromFirestore(doc);
        if (parking.expiredTimeUtc.isBefore(nowUtc)) {
          await doc.reference.update({'status': 'expired'});
        }
      }
    } catch (e) {
      print("Error auto-expiring parkings: $e");
    }
  }

  /// ----------------------------------------------------------
  /// Add Parking + Schedule Notification + store userId
  /// ----------------------------------------------------------
  Future<void> addParking(BuildContext context, Parking parking) async {
    _setLoading(true);

    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");

      final data = parking.toFirestore();
      data['userId'] = userId;
      data['status'] = 'active';

      await _parkingCollection().add(data);

      // Schedule notification
      await _scheduleParkingNotification(parking.expiredTimeUtc);

      // Auto update expired status
      await _autoExpireParkings();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Parking saved'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving parking: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _setLoading(false);
    }
  }

  /// ----------------------------------------------------------
  /// Stream all parkings (active + expired)
  /// ----------------------------------------------------------
  Stream<List<Parking>> get allParkingsStream {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value([]);

    return _parkingCollection()
        .where('userId', isEqualTo: uid)
        .orderBy('expiredTime', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
      return Parking.fromFirestore(doc);
    }).toList());
  }

  /// ----------------------------------------------------------
  /// Update Parking
  /// ----------------------------------------------------------
  Future<void> updateParking(Parking parking) async {
    try {
      await _parkingCollection().doc(parking.id).update(parking.toFirestore());

      // Cancel old notifications & schedule new one
      await notifications.cancel(1);
      await notifications.cancel(2);
      await _scheduleParkingNotification(parking.expiredTimeUtc);

      // Auto update expired status
      await _autoExpireParkings();
    } catch (e) {
      throw Exception("Update failed: $e");
    }
  }

  /// ----------------------------------------------------------
  /// Delete Parking
  /// ----------------------------------------------------------
  Future<void> deleteParking(String parkingId) async {
    try {
      await _parkingCollection().doc(parkingId).delete();

      await notifications.cancel(1);
      await notifications.cancel(2);
    } catch (e) {
      print("Error deleting parking: $e");
      rethrow;
    }
  }

  /// ----------------------------------------------------------
  /// 🔔 Schedule Notification (Malaysia timezone)
  /// ----------------------------------------------------------
  Future<void> _scheduleParkingNotification(DateTime utcExpireTime) async {
    final android = AndroidNotificationDetails(
      'parking_channel',
      'Parking Reminders',
      importance: Importance.high,
      priority: Priority.high,
    );

    final details = NotificationDetails(android: android);

    final tzTime = tz.TZDateTime.from(utcExpireTime, tz.local);

    await notifications.zonedSchedule(
      1,
      'Parking Expired',
      'Your parking time has expired. Move your car.',
      tzTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );

    final tenMinBefore = tzTime.subtract(const Duration(minutes: 10));
    if (tenMinBefore.isAfter(tz.TZDateTime.now(tz.local))) {
      await notifications.zonedSchedule(
        2,
        'Parking Reminder',
        'Your parking will expire in 10 minutes.',
        tenMinBefore,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// ----------------------------------------------------------
  /// Public method to manually check & expire parkings
  /// Can call on app start or page init
  /// ----------------------------------------------------------
  Future<void> checkAndExpireParkings() async {
    await _autoExpireParkings();
    notifyListeners();
  }
}
