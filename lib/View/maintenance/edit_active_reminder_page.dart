import 'dart:async';
import 'package:flutter/material.dart';
import 'package:ridefix/Controller/maintenance_reminder_controller.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';
import 'package:ridefix/view/maintenance/edit_reminder_form_page.dart';

class EditActiveReminderPage extends StatefulWidget {
  const EditActiveReminderPage({super.key});

  @override
  State<EditActiveReminderPage> createState() => _EditActiveReminderPageState();
}

class _EditActiveReminderPageState extends State<EditActiveReminderPage> {
  Timer? _refreshTimer;
  final controller = MaintenanceReminderController();

  @override
  void initState() {
    super.initState();
    // Refresh UI every 30 seconds to update time remaining
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  // Helper to calculate time remaining
  String _getTimeRemaining(String dateExpired, String timeExpired) {
    try {
      final reminderDate = DateTime.parse(dateExpired);
      // Parse time
      TimeOfDay timeOfDay;

      if (timeExpired.contains('AM') || timeExpired.contains('PM')) {
        final isPM = timeExpired.contains('PM');
        final timeWithoutPeriod = timeExpired
            .replaceAll(RegExp(r'[AP]M'), '')
            .trim();
        final parts = timeWithoutPeriod.split(':');
        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        if (isPM && hour != 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0;
        }

        timeOfDay = TimeOfDay(hour: hour, minute: minute);
      } else {
        final parts = timeExpired.split(':');
        timeOfDay = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }

      final reminderDateTime = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      final difference = reminderDateTime.difference(DateTime.now());

      if (difference.isNegative) return 'Expired';
      if (difference.inDays > 0)
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} left';
      if (difference.inHours > 0)
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} left';
      if (difference.inMinutes > 0)
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} left';

      return 'Less than a minute';
    } catch (e) {
      return 'Invalid date';
    }
  }

  // Color matches the time remaining
  Color _getTimeRemainingColor(String dateExpired, String timeExpired) {
    try {
      final reminderDate = DateTime.parse(dateExpired);
      TimeOfDay timeOfDay;

      if (timeExpired.contains('AM') || timeExpired.contains('PM')) {
        final isPM = timeExpired.contains('PM');
        final timeWithoutPeriod = timeExpired
            .replaceAll(RegExp(r'[AP]M'), '')
            .trim();
        final parts = timeWithoutPeriod.split(':');
        int hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        if (isPM && hour != 12) {
          hour += 12;
        } else if (!isPM && hour == 12) {
          hour = 0;
        }

        timeOfDay = TimeOfDay(hour: hour, minute: minute);
      } else {
        final parts = timeExpired.split(':');
        timeOfDay = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      }

      final reminderDateTime = DateTime(
        reminderDate.year,
        reminderDate.month,
        reminderDate.day,
        timeOfDay.hour,
        timeOfDay.minute,
      );

      final difference = reminderDateTime.difference(DateTime.now());

      if (difference.isNegative) return Colors.red;
      if (difference.inHours < 24) return Colors.orange;
      if (difference.inDays < 7) return Colors.blue;
      return Colors.green;
    } catch (e) {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Active Reminders'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => setState(() {}),
          ),
        ],
      ),
      body: StreamBuilder<List<MaintenanceReminderModel>>(
        stream: controller.getActiveReminders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            );
          }

          final reminders = snapshot.data ?? [];
          if (reminders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No active reminders found.',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'All your reminders have expired or\nyou haven\'t created any yet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
              await Future.delayed(const Duration(milliseconds: 500));
            },
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: reminders.length,
              itemBuilder: (context, index) {
                final reminder = reminders[index];
                final timeRemaining = _getTimeRemaining(
                  reminder.dateExpired,
                  reminder.timeExpired,
                );
                final timeColor = _getTimeRemainingColor(
                  reminder.dateExpired,
                  reminder.timeExpired,
                );

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  elevation: 2,
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: timeColor.withOpacity(0.2),
                      child: Icon(Icons.notifications_active, color: timeColor),
                    ),
                    title: Text(
                      reminder.maintenanceType,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'Due: ${reminder.dateExpired} at ${reminder.timeExpired}',
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: timeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: timeColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            timeRemaining,
                            style: TextStyle(
                              fontSize: 12,
                              color: timeColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                EditReminderFormPage(reminder: reminder),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
