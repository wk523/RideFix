import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String name;
  final String question;
  final String answer;
  final DateTime? createdAt;

  UserModel({
    required this.uid,
    required this.email,
    this.name = '',
    this.question = '',
    this.answer = '',
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'question': question,
      'answer': answer,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      name: map['name'] ?? '',
      question: map['question'] ?? '',
      answer: map['answer'] ?? '',
      createdAt: map['createdAt']?.toDate(),
    );
  }
}
