import 'package:cloud_firestore/cloud_firestore.dart';

class QnaModel {
  final String id;
  final String question;
  final String answer;
  final String userDocId;
  final DateTime createdAt;

  QnaModel({
    required this.id,
    required this.question,
    required this.answer,
    required this.userDocId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'answer': answer,
      'userDocId': userDocId,
      'createdAt': createdAt,
    };
  }

  factory QnaModel.fromMap(Map<String, dynamic> map, String docId) {
    return QnaModel(
      id: docId,
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
      userDocId: map['userDocId'] ?? '',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}
