import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ridefix/model/qna_model.dart';
import 'package:ridefix/model/user_model.dart';

class QnaController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload QnA and link with user UID
  Future<void> submitQnA(String question, String answer) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    if (!userDoc.exists) throw Exception("User data not found");

    final userData = UserModel.fromMap(user.uid, userDoc.data()!);

    final qna = QnaModel(
      id: '', // Firestore will generate ID automatically
      question: question,
      answer: answer,
      userDocId: userData.uid, // still link to user for reference
      createdAt: DateTime.now(),
    );

    await _firestore.collection('qna').add(qna.toMap());
  }

  /// Fetch all QnA (visible to all users)
  Stream<List<QnaModel>> getAllQnA() {
    return _firestore
        .collection('qna')
        .orderBy('createdAt', descending: true) // newest first
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => QnaModel.fromMap(doc.data(), doc.id))
        .toList());
  }
}
