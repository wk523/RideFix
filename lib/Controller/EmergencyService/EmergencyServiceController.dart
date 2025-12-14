import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:ridefix/Model/emergency_service_model.dart';
import 'dart:async';
import 'dart:math' show pi, sin, cos, sqrt, atan2;

// --- Haversine Formula (from ServicePlace.dart) ---
double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const R = 6371.0; // Earth radius in km
  final lat1Rad = lat1 * (pi / 180);
  final lon1Rad = lon1 * (pi / 180);
  final lat2Rad = lat2 * (pi / 180);
  final lon2Rad = lon2 * (pi / 180);

  final dLat = lat2Rad - lat1Rad;
  final dLon = lon2Rad - lon1Rad;

  final a =
      sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2);
  final c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c; // Distance in km
}
// --- EmergencyServiceController ---

class EmergencyServiceController extends ChangeNotifier {
  static const String GOOGLE_API_KEY =
      "AIzaSyBZWdL2ZBT8OpyGRQ-w2MS8gWKHcmdmiXQ";

  // --- State Variables ---
  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  bool _isLoading = true;
  Set<Marker> _markers = {};
  List<ServicePlace> _allServices = [];
  List<ServicePlace> _filteredServices = [];
  String _searchQuery = '';
  String _selectedFilter = 'Distance';

  static const CameraPosition kDefaultLocation = CameraPosition(
    target: LatLng(3.1390, 101.6869),
    zoom: 12,
  );

  // --- Getters ---
  GoogleMapController? get mapController => _mapController;

  LatLng? get currentPosition => _currentPosition;

  bool get isLoading => _isLoading;

  Set<Marker> get markers => _markers;

  List<ServicePlace> get filteredServices => _filteredServices;

  String get selectedFilter => _selectedFilter;

  // --- Map Handler & Location Getters ---

  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    _updateMarkersFromFilteredList();
  }

  Future<LatLng?> _getCurrentLocation(BuildContext context) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled.');
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          debugPrint('Location permission denied.');
          return null;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting location: $e');
      return null;
    }
  }

  void recenterMap(BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    final location = await _getCurrentLocation(context);

    _isLoading = false;

    if (location != null) {
      _currentPosition = location;
      _mapController?.animateCamera(CameraUpdate.newLatLng(location));
      notifyListeners();
    } else {
      notifyListeners();
    }
  }

  // --- Filtering and Sorting Logic ---

  void _calculateDistances() {
    if (_currentPosition == null) {
      _allServices = _allServices
          .map((service) => service.copyWith(distance: 0.0))
          .toList();
      return;
    }

    final userLat = _currentPosition!.latitude;
    final userLon = _currentPosition!.longitude;

    _allServices = _allServices.map((service) {
      final distance = calculateDistance(
        userLat,
        userLon,
        service.latitude,
        service.longitude,
      );
      return service.copyWith(distance: distance);
    }).toList();
  }

  void _applyFiltersAndSort() {
    // Ensure distances are calculated before sorting by distance
    _calculateDistances();

    // 1. Filtering (remains the same: apply search query)
    List<ServicePlace> results = _allServices.where((service) {
      final matchesSearch =
          _searchQuery.isEmpty ||
              service.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              service.phone.contains(_searchQuery);
      // You could add a filter here to only show favorited items if you had a 'Favorites' filter state.
      // But for now, we include all services and sort them.
      return matchesSearch;
    }).toList();

    // 2. Sorting Logic: Favorites First
    results.sort((a, b) {
      final isAFavorite = _favoriteServiceIds.contains(a.id);
      final isBFavorite = _favoriteServiceIds.contains(b.id);

      // --- Primary Sort: Favorites always come first ---
      if (isAFavorite != isBFavorite) {
        // If one is a favorite and the other isn't, the favorite gets priority.
        // We return -1 if 'a' is the favorite, and 1 if 'b' is the favorite.
        return isBFavorite ? 1 : -1;
      }

      // --- Secondary Sort: Apply selected filter (Distance or Rating) ---
      // If both are favorites (or both are NOT favorites), then we sort by distance/rating.
      if (_selectedFilter == 'Distance') {
        // Sort by distance (Nearest first, Ascending)
        return a.distanceKm.compareTo(b.distanceKm);
      } else if (_selectedFilter == 'Rating') {
        // Sort by rating (Highest first, Descending)
        return b.rating.compareTo(a.rating);
      }

      // Default: If no secondary filter applies (e.g., filter is null or custom value), keep current order.
      return 0;
    });

    _filteredServices = results;
    _updateMarkersFromFilteredList();
    // Notifies the UI (_buildServiceListSheet) to rebuild the list
    notifyListeners();
  }

  void _updateMarkersFromFilteredList() {
    _markers = {};

    if (_currentPosition != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('userLocation'),
          position: _currentPosition!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(title: 'Your Location'),
        ),
      );
    }

    for (var service in _filteredServices) {
      _markers.add(
        Marker(
          markerId: MarkerId(service.id),
          position: LatLng(service.latitude, service.longitude),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: service.name,
            snippet: '${service.distanceKm.toStringAsFixed(1)} km away',
          ),
        ),
      );
    }
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFiltersAndSort();
  }

  void setSortFilter(String filter) {
    _selectedFilter = filter;
    _applyFiltersAndSort();
  }

  void callService(String phoneNumber) async {
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    if (cleanedNumber.length < 5 || phoneNumber == 'N/A') {
      debugPrint('Cannot call: Invalid or N/A number');
      return;
    }

    final Uri launchUri = Uri(scheme: 'tel', path: cleanedNumber);

    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      debugPrint('Could not launch call to $cleanedNumber');
    }
  }

  /// ------------------------------------------------------------
  /// Function: Fetch Nearby Services (Places API)
  /// ------------------------------------------------------------
  Future<void> _fetchNearbyServices(LatLng location) async {
    // 🚩 FIX: Restored the correct, comma-separated list of recognized Place Types
    const String searchType =
        "car_repair,tow_truck,tire_shop,gas_station,car_wash,car_parts_store, ambulance, first_aid,petrol_station";

    final textSearchQuery = Uri.encodeComponent(
      "24 hour emergency service, car repair, towing, petrol station, and ambulance",
    );
    final textSearchUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/textsearch/json?'
          'query=$textSearchQuery'
          '&location=${location.latitude},${location.longitude}'
          '&radius=10000' // Text Search often uses this as a preference radius
          '&key=$GOOGLE_API_KEY',
    );

    final nearbyResponse = await http.get(textSearchUrl);

    if (nearbyResponse.statusCode != 200 ||
        nearbyResponse.body.contains("REQUEST_DENIED")) {
      debugPrint('Nearby Search API error: ${nearbyResponse.body}');
      _allServices = [];
      return;
    }

    final nearbyData = json.decode(nearbyResponse.body);
    final List<ServicePlace> fetchedPlaces = [];

    // Keywords to confirm relevance if the type is generic
    const List<String> serviceKeywords = [
      'repair',
      'service',
      'garage',
      'gas_station',
      'petrol',
      'mechanic',
      'auto',
      'towing',
      'tyre',
      'ambulance',
      'first_aid',
    ];

    // Stricter list of unwanted types
    const List<String> exclusionTypes = [
      'lodging',
      'hotel',
      'restaurant',
      'food',
      'bank',
      'park',
      'cafe',
      'bar',
      'shopping_mall',
      'gym',
    ];

    // Loop and fetch Place Details
    for (var result in nearbyData['results']) {
      final placeId = result['place_id'];
      final List<String> resultTypes = List<String>.from(result['types'] ?? []);
      final String placeName = result['name'] ?? '';

      // Check 1: Does it contain any of the explicitly excluded types?
      final bool isExcludedType = exclusionTypes.any(resultTypes.contains);
      if (isExcludedType) {
        continue;
      }

      // Check 2: Is it a core service type?
      final bool isCoreServiceType =
          resultTypes.contains('car_repair') ||
              resultTypes.contains('tow_truck') ||
              resultTypes.contains('gas_station') ||
              resultTypes.contains('petrol') ||
              resultTypes.contains('mechanic') ||
              resultTypes.contains('ambulance') ||
              resultTypes.contains('first_aid');

      // Check 3: Does the name contain a relevant service keyword?
      final bool nameIsRelevant = serviceKeywords.any(
            (k) => placeName.toLowerCase().contains(k),
      );

      // Filter final relevance: Only proceed if it is a core type OR the name is relevant.
      if (!isCoreServiceType && !nameIsRelevant) {
        continue;
      }

      // --- Data Fetching Continues ---

      const String detailFields =
          'name,vicinity,geometry,rating,user_ratings_total,formatted_phone_number';
      final detailsUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json?'
            'place_id=$placeId'
            '&fields=$detailFields'
            '&key=$GOOGLE_API_KEY',
      );

      final detailsResponse = await http.get(detailsUrl);

      if (detailsResponse.statusCode != 200 ||
          !json.decode(detailsResponse.body).containsKey('result'))
        continue;

      final detailsData = json.decode(detailsResponse.body)['result'];

      if (detailsData == null || !detailsData.containsKey('geometry')) continue;

      final lat = detailsData['geometry']['location']['lat'];
      final lng = detailsData['geometry']['location']['lng'];
      final name = detailsData['name'];

      final phone = detailsData['formatted_phone_number'] as String? ?? 'N/A';

      final rating = (detailsData['rating'] as num?)?.toDouble() ?? 0.0;
      final totalReviews =
          (detailsData['user_ratings_total'] as num?)?.toInt() ?? 0;

      final place = ServicePlace(
        id: placeId,
        name: name,
        phone: phone,
        rating: rating,
        totalReviews: totalReviews,
        latitude: lat,
        longitude: lng,
        distanceKm: 0.0,
      );

      fetchedPlaces.add(place);
    }

    _allServices = fetchedPlaces;
  }

  /// ------------------------------------------------------------
  /// Public Load Function
  /// ------------------------------------------------------------
  Future<void> loadEmergencyServices(BuildContext context) async {
    if (_currentPosition != null && _allServices.isNotEmpty && !_isLoading) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    final location = await _getCurrentLocation(context);

    final LatLng targetLocation =
        location ?? EmergencyServiceController.kDefaultLocation.target;

    if (location != null) {
      _currentPosition = location;
    }

    _mapController?.animateCamera(CameraUpdate.newLatLng(targetLocation));

    // Fetch services using the target location
    await _fetchNearbyServices(targetLocation);

    // Apply filters/sort and update UI
    _applyFiltersAndSort();

    _isLoading = false;
    notifyListeners();
  }

  /// Fetches a human-readable address from the current location.
  Future<String> fetchAddressFromControllerLocation() async {
    final LatLng? location = _currentPosition;

    if (location == null) {
      return "GPS location unavailable. Please ensure location services are enabled and re-center the map.";
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        // Construct a concise address (e.g., street, sub-locality, city, state)
        String address =
            "${place.street ?? ''}, ${place.subLocality ?? place.locality ??
            ''}, ${place.administrativeArea ?? ''}";
        // Clean up multiple commas
        return address
            .replaceAll(RegExp(r',\s*,'), ', ')
            .trim()
            .replaceAll(RegExp(r'^,\s*'), '');
      } else {
        return "Address not found for coordinates.";
      }
    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
      return "Error retrieving address.";
    }
  }


  /// Streams the list of saved emergency contacts for the given user ID.
  Stream<List<EmergencyContact>> emergencyContactsStream(String uid) {
    return FirebaseFirestore.instance
        .collection('EmergencyContact')
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      return snap.docs.map((d) => EmergencyContact.fromFirestore(d)).toList();
    });
  }

  /// Saves a new emergency contact to the Firestore collection.
  Future<void> saveEmergencyContact({
    required String uid,
    required String name,
    required String number,
  }) async {
    // Save to Firestore, ensuring the number is clean and the UID is present for querying.
    await FirebaseFirestore.instance.collection('EmergencyContact').add({
      'uid': uid,
      'name': name.trim(),
      // Remove non-digit characters for clean number storage
      'number': number.replaceAll(RegExp(r'[^\d+]'), '').trim(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Sends the formatted SOS message using the WhatsApp deep link,
  /// with multiple fallbacks if the direct app link fails.
  Future<void> sendSosWhatsApp({
    required String recipientNumber,
    required String message,
  }) async {
    // 1. Clean the number to digits only, keeping the '+' initially for cleaning.
    final rawCleanedNumber = recipientNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // 2. Prepare phone numbers for different formats:
    // a) App link number (CountryCode + Digits, NO '+', e.g., 6018...)
    final whatsappAppNumber = rawCleanedNumber.startsWith('+')
        ? rawCleanedNumber.substring(1)
        : rawCleanedNumber;

    // b) Web link number (CountryCode + Digits, NO '+', e.g., 6018...)
    //    This is the same as the app number, but used in the web link.
    final whatsappWebNumber = whatsappAppNumber;

    // c) SMS number (Often works best with the '+' prefix, e.g., +6018...)
    final smsNumber = rawCleanedNumber;

    final encodedMessage = Uri.encodeComponent(message);

    // --- Attempt 1: WhatsApp Deep Link (App-specific) ---
    final Uri appLaunchUri = Uri.parse(
      'whatsapp://send?phone=$whatsappAppNumber&text=$encodedMessage',
    );

    if (await canLaunchUrl(appLaunchUri)) {
      try {
        await launchUrl(appLaunchUri, mode: LaunchMode.externalApplication);
        return; // Success, exit function
      } catch (e) {
        debugPrint('WhatsApp App Link failed: $e. Trying web link.');
        // Continue to next attempt if the app link fails
      }
    }

    // --- Attempt 2: WhatsApp Web Link (Universal Fallback) ---
    // This URL opens in a browser or the WhatsApp app via a browser redirect.
    final Uri webLaunchUri = Uri.parse(
      'https://wa.me/$whatsappWebNumber?text=$encodedMessage', // <--- Use this link format
    );

    if (await canLaunchUrl(webLaunchUri)) {
      try {
        await launchUrl(webLaunchUri, mode: LaunchMode.externalApplication);
        return; // Success, exit function
      } catch (e) {
        debugPrint('WhatsApp Web Link failed: $e. Trying SMS.');
        // Continue to next attempt
      }
    }


    // --- Attempt 3: SMS Fallback ---
    final smsUri = Uri(scheme: 'sms',
        path: smsNumber,
        queryParameters: {'body': message});

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri, mode: LaunchMode.platformDefault);
    } else {
      // Final failure message (you should show this to the user)
      debugPrint('FINAL FAILURE: Could not launch WhatsApp or SMS. Check number format and device setup.');
      // You would typically show a Snackbar or AlertDialog here.
      // Example: ScaffoldMessenger.of(context).showSnackBar(...)
    }
  }


  /// Handles the complete SOS submission process (Firestore save, call, and message).
  Future<void> sendSosRequest({
    required String address,
    required List<String> selectedIssues,
    required String plateNumber,
    required String vehicleBrand,
    required String vehicleModel,
    required DocumentSnapshot userDoc,
    required String emergencyContactNumber,
    required String emergencyContactName,
  }) async {
    final LatLng? userLocation = _currentPosition;

    if (userLocation == null) {
      throw Exception('Current location is unknown. Cannot send SOS.');
    }

    final Map<String, dynamic> userData = (userDoc.data() as Map<String, dynamic>? ?? {});
    final String userName = userData['name'] ?? 'App User';

    final String vehicleDisplay = (vehicleBrand.isNotEmpty && vehicleModel.isNotEmpty)
        ? '$vehicleBrand $vehicleModel ($plateNumber)'
        : (plateNumber.isEmpty ? 'N/A' : plateNumber);

    // ✅ NEW: Create the clickable Google Maps URL
    final String mapUrl = 'https://maps.google.com/?q=${userLocation.latitude},${userLocation.longitude}';
    // final String mapUrl = 'https://www.google.com/maps/search/?api=1&query=${userLocation.latitude},${userLocation.longitude}';

    // 1. Compile SOS Message (Updated GPS line to be clickable)
    final sosMessage = '''
🚨 URGENT: ROADSIDE ASSISTANCE NEEDED! 🚨
This is an automated SOS from $userName.

I am currently experiencing a vehicle issue.

Details:
- Vehicle: $vehicleDisplay
- Problem(s): ${selectedIssues.join(', ')}
- Location: $address
- GPS Link: $mapUrl
- Time: ${DateTime.now().toLocal().toString().substring(11, 16)}

Please help me immediately or contact emergency services.
''';

    // 2. Submit to Firestore (Sos Request) - Data structure remains the same
    await FirebaseFirestore.instance.collection('sos_requests').add({
      'timestamp': FieldValue.serverTimestamp(),
      'user_id': userDoc.id,
      'latitude': userLocation.latitude,
      'longitude': userLocation.longitude,
      'issues': selectedIssues.join('; '),
      'vehicle_plate': plateNumber.isEmpty ? 'N/A' : plateNumber,
      'vehicle_brand': vehicleBrand,
      'vehicle_model': vehicleModel,
      'location_address': address,
      'contact_name': emergencyContactName,
      'contact_number': emergencyContactNumber,
      'status': 'Pending',
    });

    // 3. Send WhatsApp message to the selected contact
    if (emergencyContactNumber != 'N/A') {
      sendSosWhatsApp(
        recipientNumber: emergencyContactNumber,
        message: sosMessage,
      );
    }
  }

  Set<String> _favoriteServiceIds = {};
  Set<String> get favoriteServiceIds => _favoriteServiceIds;

// You'll need a method to load favorites when the controller initializes or the user changes.
  Future<void> loadFavorites(String userId) async {
    try {
      // FIX: Reference the new top-level collection and filter by userId
      final snapshot = await FirebaseFirestore.instance
          .collection('FavouriteService')
          .where('userId', isEqualTo: userId) // Filter to get only this user's favorites
          .get();

      _favoriteServiceIds = snapshot.docs
          .map((doc) => doc.data()['serviceId'] as String)
          .where((id) => id.isNotEmpty)
          .toSet();

      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
  }

// Toggles the favorite status of a service for a specific user.
  Future<void> toggleFavorite(String userId, ServicePlace service) async {
    // FIX: Reference the new top-level collection
    final favoritesRef = FirebaseFirestore.instance.collection('FavouriteService');

    if (_favoriteServiceIds.contains(service.id)) {
      // Service is currently a favorite, so remove it
      final querySnapshot = await favoritesRef
          .where('userId', isEqualTo: userId)      // Filter by current user
          .where('serviceId', isEqualTo: service.id) // Filter by service ID
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.delete();
        _favoriteServiceIds.remove(service.id);
        debugPrint('Removed ${service.name} from favorites.');
      }
    } else {
      // Service is not a favorite, so add it
      await favoritesRef.add({
        'userId': userId,                     // IMPORTANT: Save the user ID as a field
        'serviceId': service.id,
        'serviceName': service.name,
        'addedAt': FieldValue.serverTimestamp(),
      });
      _favoriteServiceIds.add(service.id);
      debugPrint('Added ${service.name} to favorites.');
    }

    notifyListeners();
  }
}
