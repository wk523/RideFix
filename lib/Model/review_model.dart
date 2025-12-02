
import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String reviewId;        // ← 添加这个
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime? createdAt;

  Review({
    required this.reviewId,     // ← 添加这个
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    this.createdAt,
  });

  factory Review.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Review(
      reviewId: doc.id,          // ← 添加这个（从 Firestore document ID 获取）
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 0).toDouble(),
      comment: data['comment'] ?? '',
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as Timestamp).toDate()
          : null,
    );
  }

  // 可选：添加 toMap 方法（如果需要保存到 Firestore）
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}