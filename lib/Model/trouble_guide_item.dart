import 'package:cloud_firestore/cloud_firestore.dart';

class TroubleGuideItem {
  final String id;
  final String title;
  final String description;
  final String videoImage;
  final String videoUrl;
  final String category;

  TroubleGuideItem({
    required this.id,
    required this.title,
    required this.description,
    required this.videoImage,
    required this.videoUrl,
    required this.category,
  });

  factory TroubleGuideItem.fromFirestore(Map<String, dynamic> data, String id) {
    return TroubleGuideItem(
      id: id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      videoImage: data['videoImage'] ?? '',
      videoUrl: data['videoUrl'] ?? '',
      category: data['category'] ?? '',
    );
  }
}
