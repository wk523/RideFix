import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/controller/parking_controller.dart';
import 'package:ridefix/model/parking_model.dart';
import 'package:ridefix/view/parking/edit_parking_form_page.dart';
import 'package:ridefix/view/parking/parking_details_card.dart';

class EditActiveParkingPage extends StatefulWidget {
  const EditActiveParkingPage({super.key});

  @override
  State<EditActiveParkingPage> createState() => _EditActiveParkingPageState();
}

class _EditActiveParkingPageState extends State<EditActiveParkingPage> {
  final ParkingController _controller = ParkingController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // refresh every 1 sec
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Convert UTC → Malaysia local
  DateTime _toMalaysia(DateTime utcInstant) =>
      utcInstant.toUtc().add(const Duration(hours: 8));

  /// Countdown display
  String _countDown(DateTime dueUtc) {
    final diff = dueUtc.difference(DateTime.now().toUtc());

    if (diff.isNegative) return "Expired";

    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;

    return "${d}d ${h}h ${m}m ${s}s";
  }

  /// Countdown color logic
  Color _countdownColor(DateTime dueUtc) {
    final diff = dueUtc.difference(DateTime.now().toUtc());

    if (diff.isNegative) return Colors.red;
    if (diff.inHours < 1) return Colors.redAccent;
    if (diff.inHours < 12) return Colors.orange;
    if (diff.inDays < 1) return Colors.blue;
    return Colors.green;
  }

  /// Delete popup confirmation
  void _confirmDelete(BuildContext context, Parking parking) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove Parking Reminder"),
        content: const Text("Are you sure you want to remove this reminder?"),
        actions: [
          TextButton(
            child: const Text("Cancel"),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            child: const Text("Remove"),
            onPressed: () async {
              await _controller.deleteParking(parking.id!);
              if (mounted) Navigator.pop(context);
            },
          )
        ],
      ),
    );
  }

  /// View detail popup using ParkingDetailsCard
  void _showDetailCard(Parking parking) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ParkingDetailsCard(
          parking: parking,
          onDelete: () {
            Navigator.pop(context);
            _confirmDelete(context, parking);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Parking Reminders")),
      body: StreamBuilder<List<Parking>>(
        stream: _controller.allParkingsStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final list = snapshot.data!;
          if (list.isEmpty) {
            return const Center(
              child: Text("No parking reminders."),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            itemBuilder: (context, index) {
              final parking = list[index];

              final malaysiaTime = _toMalaysia(parking.expiredTimeUtc);
              final isExpired =
              parking.expiredTimeUtc.isBefore(DateTime.now().toUtc());
              final color = _countdownColor(parking.expiredTimeUtc);

              return Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                elevation: 4,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: color.withOpacity(0.2),
                          child: Icon(Icons.local_parking,
                              color: color, size: 28),
                        ),
                        title: Text(
                          "Parking: ${parking.parkingFloor}/${parking.lotNum}",
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          "Expire: ${DateFormat('yyyy-MM-dd HH:mm').format(malaysiaTime)} (MYT)",
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Countdown badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isExpired
                              ? "Expired"
                              : _countDown(parking.expiredTimeUtc),
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          // View detail
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showDetailCard(parking),
                              icon: const Icon(Icons.remove_red_eye),
                              label: const Text("View"),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor: Colors.grey.shade700,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Edit button — disabled if expired
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: isExpired
                                  ? null
                                  : () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        EditParkingFormPage(
                                            parking: parking),
                                  ),
                                );
                                if (mounted) setState(() {});
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text("Edit"),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.black,
                                backgroundColor:
                                isExpired ? Colors.grey : Colors.blueAccent,
                                minimumSize: const Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
