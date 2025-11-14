import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ridefix/View/troubleshoot/qna_upload_view.dart';
import 'package:ridefix/controller/qna_controller.dart';
import 'package:ridefix/model/qna_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QnaListView extends StatelessWidget {
  final QnaController controller = QnaController();

  QnaListView({super.key});

  /// Fetch username by userDocId
  Future<String> getUserName(String userId) async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (doc.exists) {
      final data = doc.data();
      return data?['name'] ?? 'Unknown';
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Q&A'),
        backgroundColor: Colors.teal,
      ),
      body: StreamBuilder<List<QnaModel>>(
        stream: controller.getAllQnA(), // fetch all QnA
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final qnas = snapshot.data ?? [];

          if (qnas.isEmpty) {
            return const Center(
              child: Text(
                "No Q&A uploaded yet.\nTap the '+' button to add one.",
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: qnas.length,
            itemBuilder: (context, index) {
              final qna = qnas[index];

              return FutureBuilder<String>(
                future: getUserName(qna.userDocId), // fetch user name dynamically
                builder: (context, userSnapshot) {
                  final userName = userSnapshot.data ?? 'Unknown';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Q: ${qna.question}",
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "A: ${qna.answer}",
                            style: const TextStyle(fontSize: 15),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Posted by: $userName on ${qna.createdAt.toLocal().toString().split('.')[0]}",
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.teal,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QnaUploadView()),
          );
        },
        label: const Text("Upload Q&A"),
        icon: const Icon(Icons.upload),
      ),
    );
  }
}
