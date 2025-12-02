import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ridefix/Controller/workshop_controller.dart';
import 'package:ridefix/Model/review_model.dart' as AppReview;

class WorkshopDetailsPage extends StatelessWidget {
  final String placeId;
  final String workshopName;

  const WorkshopDetailsPage({Key? key, required this.placeId, required this.workshopName}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WorkshopController(),
      child: _WorkshopDetailsContent(placeId: placeId, workshopName: workshopName),
    );
  }
}

class _WorkshopDetailsContent extends StatelessWidget {
  final String placeId;
  final String workshopName;

  const _WorkshopDetailsContent({required this.placeId, required this.workshopName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Workshop Details'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(workshopName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
            const Divider(thickness: 2),
            _buildAddReviewSection(context, placeId, workshopName),
            const Divider(thickness: 2),
            _buildReviewsList(context, placeId),
          ],
        ),
      ),
    );
  }

  Widget _buildAddReviewSection(BuildContext context, String placeId, String workshopName) {
    final controller = Provider.of<WorkshopController>(context, listen: false);
    final TextEditingController commentController = TextEditingController();
    double userRating = 3.0;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Add Your RideFix Review', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StatefulBuilder(
            builder: (context, setState) {
              return Row(
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < userRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 32,
                    ),
                    onPressed: () => setState(() => userRating = index + 1.0),
                  );
                }),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: commentController,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'Your comment...',
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                controller.addReview(
                  context,
                  placeId: placeId,
                  workshopName: workshopName,
                  rating: userRating,
                  comment: commentController.text,
                );
                commentController.clear();
              },
              child: const Text('Submit Review'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsList(BuildContext context, String placeId) {
    final controller = Provider.of<WorkshopController>(context, listen: false);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('RideFix User Reviews', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          StreamBuilder<List<AppReview.Review>>(
            stream: controller.getReviewsForWorkshop(placeId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const Text('No RideFix reviews yet. Be the first to add one!');
              }
              final reviews = snapshot.data!;
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: reviews.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final review = reviews[index];
                  final isOwner = review.userId == currentUserId;

                  return ListTile(
                    title: Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review.comment),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(review.rating.toStringAsFixed(1)),
                            const SizedBox(width: 4),
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                          ],
                        ),
                      ],
                    ),
                    trailing: isOwner
                        ? PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditDialog(context, controller, review, placeId, workshopName);
                        } else if (value == 'delete') {
                          _showDeleteDialog(context, controller, review.reviewId, placeId);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, size: 20),
                              SizedBox(width: 8),
                              Text('Edit'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, size: 20, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      ],
                    )
                        : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(review.rating.toStringAsFixed(1)),
                        const SizedBox(width: 4),
                        const Icon(Icons.star, color: Colors.amber, size: 16),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  // 编辑对话框
  void _showEditDialog(BuildContext context, WorkshopController controller,
      AppReview.Review review, String placeId, String workshopName) {
    final TextEditingController editController = TextEditingController(text: review.comment);
    double editRating = review.rating;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Edit Review'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Rating:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 0,
                      children: List.generate(5, (index) {
                        return IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            index < editRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 28,
                          ),
                          onPressed: () => setState(() => editRating = index + 1.0),
                        );
                      }),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: editController,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        labelText: 'Comment',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    controller.updateReview(
                      context,
                      reviewId: review.reviewId,
                      placeId: placeId,
                      workshopName: workshopName,
                      rating: editRating,
                      comment: editController.text,
                    );
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // 删除确认对话框
  void _showDeleteDialog(BuildContext context, WorkshopController controller,
      String reviewId, String placeId) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete Review'),
          content: const Text('Are you sure you want to delete this review?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                controller.deleteReview(context, reviewId: reviewId, placeId: placeId);
                Navigator.pop(dialogContext);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }
}