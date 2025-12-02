import 'package:cloud_firestore/cloud_firestore.dart';

class Parking {
  final DateTime expiredTimeUtc; // Stored in Firestore as UTC
  final double latitude;
  final double longitude;
  final String lotNum;
  final String parkingFloor;
  final String? id;

  Parking({
    required this.expiredTimeUtc,
    required this.latitude,
    required this.longitude,
    required this.lotNum,
    required this.parkingFloor,
    this.id,
  });

  /// Firestore -> Parking
  factory Parking.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final Timestamp ts = data['expiredTime'];
    final DateTime utc = ts.toDate().toUtc();

    return Parking(
      id: doc.id,
      expiredTimeUtc: utc,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      lotNum: data['lotNum']?.toString() ?? '',
      parkingFloor: data['parkingFloor']?.toString() ?? '',
    );
  }

  /// Parking -> Firestore map (store as UTC Timestamp)
  Map<String, dynamic> toFirestore() {
    return {
      'expiredTime': Timestamp.fromDate(expiredTimeUtc),
      'latitude': latitude,
      'longitude': longitude,
      'lotNum': lotNum,
      'parkingFloor': parkingFloor,
      'status': expiredTimeUtc.isBefore(DateTime.now().toUtc())
          ? 'expired'
          : 'active',
    };
  }


  /// Helper to get expired time in Malaysia (UTC+8)
  DateTime get expiredTimeMalaysia => expiredTimeUtc.add(const Duration(hours: 8));
}