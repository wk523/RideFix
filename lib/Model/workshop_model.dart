
import 'package:google_maps_flutter/google_maps_flutter.dart';

class WorkshopLocation {
  final double lat;
  final double lng;

  WorkshopLocation({required this.lat, required this.lng});
}

class Workshop {
  final String placeId;
  final String name;
  final String address;
  final double rating;
  final WorkshopLocation location;

  Workshop({
    required this.placeId,
    required this.name,
    required this.address,
    required this.location,
    this.rating = 0,
  });

  // Optional: Factory from Google Places API JSON
  factory Workshop.fromJson(Map<String, dynamic> json) {
    final loc = json['geometry']['location'];
    return Workshop(
      placeId: json['place_id'],
      name: json['name'] ?? "Unnamed Workshop",
      address: json['vicinity'] ?? "Unknown Address",
      rating: (json['rating'] ?? 0).toDouble(),
      location: WorkshopLocation(lat: loc['lat'], lng: loc['lng']),
    );
  }
}
