// lib/Controller/workshop_controller.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_google_places_sdk/flutter_google_places_sdk.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:http/http.dart' as http;

import '../Model/workshop_model.dart';
import '../Model/review_model.dart' as AppReview;

class SimplePrediction {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  SimplePrediction({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });
}

class WorkshopController extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  static const String _apiKey = 'AIzaSyBZWdL2ZBT8OpyGRQ-w2MS8gWKHcmdmiXQ';
  final FlutterGooglePlacesSdk places = FlutterGooglePlacesSdk(_apiKey);

  bool _isLoading = false;
  Position? _currentPosition;
  List<Workshop> _workshops = [];
  List<SimplePrediction> _predictions = [];
  gmaps.GoogleMapController? _mapController;

  bool get isLoading => _isLoading;
  Position? get currentPosition => _currentPosition;
  List<Workshop> get workshops => _workshops;
  List<SimplePrediction> get predictions => _predictions;

  WorkshopController() {
    initController();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setMapController(gmaps.GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> initController() async {
    _setLoading(true);
    await _getUserLocation();
    await searchNearbyWorkshops();
    _setLoading(false);
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint("Location permissions are permanently denied");
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      notifyListeners();
    } catch (e) {
      debugPrint("Error getting location: $e");
    }
  }

  // -------------------------
  // 🔥 改进：使用 Text Search 直接搜索工坊
  // -------------------------
  Future<void> getAutocompleteSuggestions(String input) async {
    if (input.isEmpty) {
      _predictions = [];
      notifyListeners();
      return;
    }

    try {
      if (_currentPosition == null) {
        debugPrint("No location for autocomplete");
        return;
      }

      // 使用 Autocomplete API 搜索工坊和汽修相关的地点
      final url = "https://maps.googleapis.com/maps/api/place/autocomplete/json?"
          "input=$input"
          "&location=${_currentPosition!.latitude},${_currentPosition!.longitude}"
          "&radius=50000"
          "&types=establishment"
          "&components=country:my"
          "&key=$_apiKey";

      debugPrint("Autocomplete URL: $url");

      final response = await http.get(Uri.parse(Uri.encodeFull(url)));
      final data = json.decode(response.body);

      if (data["status"] == "OK" && data["predictions"] != null) {
        _predictions = (data["predictions"] as List).map((p) {
          return SimplePrediction(
            placeId: p["place_id"] ?? '',
            description: p["description"] ?? '',
            mainText: p["structured_formatting"]?["main_text"] ?? '',
            secondaryText: p["structured_formatting"]?["secondary_text"] ?? '',
          );
        }).take(5).toList(); // 只显示前5个结果

        debugPrint("Found ${_predictions.length} suggestions");
      } else {
        debugPrint("Autocomplete API status: ${data["status"]}");
        _predictions = [];
      }
    } catch (e) {
      debugPrint("Autocomplete error: $e");
      _predictions = [];
    }
    notifyListeners();
  }

  // -------------------------
  // 点击建议 -> 搜索该位置附近的工坊
  // -------------------------
  Future<void> searchAtPlace(String placeId) async {
    if (placeId.isEmpty) return;

    _setLoading(true);
    _predictions = []; // 清空建议
    notifyListeners();

    try {
      // 获取选中地点的详细信息
      final url = "https://maps.googleapis.com/maps/api/place/details/json?"
          "place_id=$placeId"
          "&fields=geometry,name,formatted_address,types"
          "&key=$_apiKey";

      final response = await http.get(Uri.parse(url));
      final data = json.decode(response.body);

      if (data["status"] == "OK" && data["result"] != null) {
        final result = data["result"];
        final geometry = result["geometry"]?["location"];
        final types = result["types"] as List<dynamic>?;

        if (geometry != null) {
          final lat = geometry["lat"].toDouble();
          final lng = geometry["lng"].toDouble();

          debugPrint("Selected place: ${result["name"]}");
          debugPrint("Types: $types");

          // 更新地图位置
          _mapController?.animateCamera(
            gmaps.CameraUpdate.newLatLngZoom(gmaps.LatLng(lat, lng), 15),
          );

          // 检查是否是工坊类型的地点
          bool isWorkshop = types?.any((type) =>
          type.toString().contains('car_repair') ||
              type.toString().contains('car_dealer') ||
              type.toString().contains('car_wash')
          ) ?? false;

          if (isWorkshop) {
            // 如果选中的就是工坊，直接添加到列表
            _workshops = [
              Workshop(
                placeId: placeId,
                name: result["name"] ?? "Workshop",
                address: result["formatted_address"] ?? "Unknown Address",
                rating: (result["rating"] ?? 0.0).toDouble(),
                location: WorkshopLocation(lat: lat, lng: lng),
              )
            ];
            debugPrint("Added workshop directly");
          } else {
            // 否则搜索该位置附近的工坊
            await searchNearbyWorkshops(lat: lat, lng: lng);
          }
        }
      } else {
        debugPrint("Place Details API error: ${data["status"]}");
      }
    } catch (e) {
      debugPrint("searchAtPlace error: $e");
    }
    _setLoading(false);
  }

  // -------------------------
  // 使用关键词搜索附近工坊（支持直接输入搜索）
  // -------------------------
  Future<void> searchNearbyWorkshops({
    double? lat,
    double? lng,
    String keyword = "car workshop",
  }) async {
    _setLoading(true);
    try {
      final targetLat = lat ?? _currentPosition?.latitude;
      final targetLng = lng ?? _currentPosition?.longitude;

      if (targetLat == null || targetLng == null) {
        debugPrint("No location available for search");
        _workshops = [];
        _setLoading(false);
        return;
      }

      final url = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?"
          "location=$targetLat,$targetLng"
          "&radius=10000"
          "&keyword=$keyword"
          "&type=car_repair"
          "&key=$_apiKey";

      debugPrint("Searching workshops at: $targetLat, $targetLng with keyword: $keyword");

      final response = await http.get(Uri.parse(Uri.encodeFull(url)));
      final data = json.decode(response.body);

      debugPrint("API Response Status: ${data["status"]}");

      if (data["status"] == "ZERO_RESULTS") {
        debugPrint("No workshops found in this area");
        _workshops = [];
        _setLoading(false);
        notifyListeners();
        return;
      }

      if (data["status"] != "OK") {
        debugPrint("Places API error: ${data["status"]}");
        if (data["error_message"] != null) {
          debugPrint("Error message: ${data["error_message"]}");
        }
        _workshops = [];
        _setLoading(false);
        notifyListeners();
        return;
      }

      if (data["results"] != null && (data["results"] as List).isNotEmpty) {
        _workshops = (data["results"] as List).map<Workshop>((w) {
          final loc = w["geometry"]["location"];
          return Workshop(
            placeId: w["place_id"] ?? '',
            name: w["name"] ?? "Unnamed Workshop",
            address: w["vicinity"] ?? "Unknown Address",
            rating: (w["rating"] ?? 0.0).toDouble(),
            location: WorkshopLocation(
              lat: loc["lat"].toDouble(),
              lng: loc["lng"].toDouble(),
            ),
          );
        }).toList();

        debugPrint("Found ${_workshops.length} workshops");
      } else {
        debugPrint("No workshops in results");
        _workshops = [];
      }
    } catch (e) {
      debugPrint("Nearby search error: $e");
      _workshops = [];
    }
    notifyListeners();
    _setLoading(false);
  }

  // 计算距离
  double? getDistanceToWorkshop(Workshop workshop) {
    if (_currentPosition == null) return null;
    return Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      workshop.location.lat,
      workshop.location.lng,
    );
  }

  // -------------------------
  // Firestore Reviews
  // -------------------------
  Stream<List<AppReview.Review>> getReviewsForWorkshop(String placeId) {
    return _firestore
        .collection('workshop_reviews')
        .doc(placeId)
        .collection('reviews')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
        snapshot.docs.map((doc) => AppReview.Review.fromFirestore(doc)).toList());
  }
// 在你的 WorkshopController 类中添加：

// 更新评论
  Future<void> updateReview(
      BuildContext context, {
        required String reviewId,
        required String placeId,
        required String workshopName,
        required double rating,
        required String comment,
      }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(reviewId)
          .update({
        'rating': rating,
        'comment': comment,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review updated successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating review: $e')),
      );
    }
  }

// 删除评论
  Future<void> deleteReview(
      BuildContext context, {
        required String reviewId,
        required String placeId,
      }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first')),
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('reviews')
          .doc(reviewId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting review: $e')),
      );
    }
  }
  Future<void> addReview(
      BuildContext context, {
        required String placeId,
        required String workshopName,
        required double rating,
        required String comment,
      }) async {
    final user = _auth.currentUser;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to post a review.')),
        );
      }
      return;
    }
    if (comment.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields.')),
        );
      }
      return;
    }

    _setLoading(true);
    final reviewDocRef = _firestore.collection('workshop_reviews').doc(placeId);

    try {
      await reviewDocRef.set({'name': workshopName}, SetOptions(merge: true));
      await reviewDocRef.collection('reviews').add({
        'workshopId': placeId,
        'userId': user.uid,
        'userName': user.displayName ?? 'Anonymous User',
        'rating': rating,
        'comment': comment,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review submitted successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _setLoading(false);
    }
  }
}