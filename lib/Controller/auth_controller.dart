import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ridefix/model/user_model.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> registerUser(String email, String password) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;

    UserModel newUser = UserModel(
      uid: uid,
      email: email,
      createdAt: DateTime.now(), // local reference, optional
    );

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': '',
      'createdAt': FieldValue.serverTimestamp(), // ✅ correct
    });
  }
}
