import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ridefix/controller/maintenance_reminder_controller.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';
import 'package:ridefix/view/maintenance/edit_reminder_form_page.dart';

class EditActiveReminderPage extends StatefulWidget {
  const EditActiveReminderPage({super.key});

  @override
  State<EditActiveReminderPage> createState() => _EditActiveReminderPageState();
}

class _EditActiveReminderPageState extends State<EditActiveReminderPage> {
  final _controller = MaintenanceReminderController();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Refresh every second for countdown
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // convert UTC instant -> Malaysia local
  DateTime _toMalaysiaLocal(DateTime utcInstant) => utcInstant.toUtc().add(const Duration(hours: 8));

  // Countdown and colors operate on UTC to avoid timezone issues
  String _countDown(DateTime dueUtc) {
    final diff = dueUtc.difference(DateTime.now().toUtc());
    if (diff.isNegative) return "Expired";

    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final s = diff.inSeconds % 60;

    return "${d}d ${h}h ${m}m ${s}s";
  }

  Color _timeColor(DateTime dueUtc) {
    final diff = dueUtc.difference(DateTime.now().toUtc());
    if (diff.isNegative) return Colors.red;
    if (diff.inHours < 24) return Colors.orange;
    if (diff.inDays < 7) return Colors.blue;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Active Reminders')),
      body: StreamBuilder<List<MaintenanceReminderModel>>(
        stream: _controller.getActiveReminders(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final reminders = snapshot.data!;
          if (reminders.isEmpty) return const Center(child: Text("No active reminders."));

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: reminders.length,
            itemBuilder: (context, index) {
              final r = reminders[index];
              final dueMalaysia = _toMalaysiaLocal(r.dueDateTime);
              final color = _timeColor(r.dueDateTime);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: CircleAvatar(
                    backgroundColor: color.withOpacity(0.2),
                    child: Icon(Icons.timer, color: color),
                  ),
                  title: Text(r.maintenanceType, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("Due: ${DateFormat('yyyy-MM-dd HH:mm').format(dueMalaysia)} (MYT)"),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _countDown(r.dueDateTime),
                          style: TextStyle(fontWeight: FontWeight.bold, color: color),
                        ),
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => EditReminderFormPage(reminder: r)),
                      );
                      if (mounted) setState(() {});
                    },
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
