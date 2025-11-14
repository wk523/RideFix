import 'package:flutter/material.dart';
import 'package:ridefix/controller/qna_controller.dart';

class QnaUploadView extends StatefulWidget {
  const QnaUploadView({super.key});

  @override
  State<QnaUploadView> createState() => _QnaUploadViewState();
}

class _QnaUploadViewState extends State<QnaUploadView> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  final QnaController controller = QnaController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Q&A")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _questionController,
                decoration: const InputDecoration(labelText: 'Question'),
                validator: (value) => value!.isEmpty ? "Enter a question" : null,
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _answerController,
                decoration: const InputDecoration(labelText: 'Answer'),
                validator: (value) => value!.isEmpty ? "Enter an answer" : null,
              ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    await controller.submitQnA(
                      _questionController.text.trim(),
                      _answerController.text.trim(),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Q&A uploaded successfully")),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: const Text("Submit"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
