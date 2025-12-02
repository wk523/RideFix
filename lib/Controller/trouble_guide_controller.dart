import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ridefix/model/trouble_guide_item.dart';

class TroubleGuideController {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<List<TroubleGuideItem>> streamByCategory(String category) {
    return _firestore
        .collection('Troubleguide')
        .where('category', isEqualTo: category)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => TroubleGuideItem.fromFirestore(doc.data() as Map<String, dynamic>, doc.id))
        .toList());
  }
}
