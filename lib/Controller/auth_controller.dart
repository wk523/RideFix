import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ridefix/model/user_model.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 接收 name
  Future<void> registerUser(String email, String password, String name) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = userCredential.user!.uid;

    UserModel newUser = UserModel(
      uid: uid,
      email: email,
      name: name,                     // <-- 新增
      createdAt: DateTime.now(),
    );

    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': name,                   // <-- 新增
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
