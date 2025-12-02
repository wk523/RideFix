import 'package:flutter/material.dart';
import 'package:ridefix/Model/workshop_model.dart';
import 'package:ridefix/View/workshop/workshop_details_page.dart';

class WorkshopListItemCard extends StatelessWidget {
  final Workshop workshop;
  final double? distanceInMeters;

  const WorkshopListItemCard({
    Key? key,
    required this.workshop,
    this.distanceInMeters,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final distanceInKm = distanceInMeters != null
        ? (distanceInMeters! / 1000).toStringAsFixed(1)
        : null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => WorkshopDetailsPage(
                placeId: workshop.placeId,
                workshopName: workshop.name,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workshop.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(
                          workshop.rating != null
                              ? workshop.rating!.toStringAsFixed(1)
                              : 'No rating',
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (distanceInKm != null)
                      Text(
                        'Distance: $distanceInKm km',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WorkshopDetailsPage(
                        placeId: workshop.placeId,
                        workshopName: workshop.name,
                      ),
                    ),
                  );
                },
                child: const Text('View'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
