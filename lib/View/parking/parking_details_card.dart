import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ridefix/model/parking_model.dart';

class ParkingDetailsCard extends StatelessWidget {
  final Parking parking;
  final VoidCallback onDelete;

  const ParkingDetailsCard({
    super.key,
    required this.parking,
    required this.onDelete,
  });

  /// 打开 Google Map (App / Browser)
  Future<void> _openInGoogleMaps() async {
    final double lat = parking.latitude;
    final double lng = parking.longitude;

    final Uri googleMapsUrl = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng");

    if (await canLaunchUrl(googleMapsUrl)) {
      await launchUrl(googleMapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Parking Details",
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 10),

            Text("Location:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Floor: ${parking.parkingFloor}",
                style: const TextStyle(fontSize: 16)),
            Text("Lot: ${parking.lotNum}",
                style: const TextStyle(fontSize: 16)),

            const SizedBox(height: 12),

            Text("Coordinates:",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text("Lat: ${parking.latitude}",
                style: const TextStyle(fontSize: 15)),
            Text("Lng: ${parking.longitude}",
                style: const TextStyle(fontSize: 15)),

            const SizedBox(height: 12),

            Text("Expires (Malaysia Time):",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(parking.expiredTimeMalaysia.toString(),
                style: const TextStyle(fontSize: 15)),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openInGoogleMaps,
                    icon: const Icon(Icons.location_on),
                    label: const Text("View on Map"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete),
                    label: const Text("Remove"),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black,
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
