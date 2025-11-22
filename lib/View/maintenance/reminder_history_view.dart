import 'package:flutter/material.dart';
import 'package:ridefix/controller/maintenance_reminder_controller.dart';
import 'package:ridefix/model/maintenance_reminder_model.dart';
import 'package:intl/intl.dart';

class ReminderHistoryView extends StatelessWidget {
  const ReminderHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = MaintenanceReminderController();

    return Scaffold(
      appBar: AppBar(title: const Text('Reminder History')),
      body: StreamBuilder<List<MaintenanceReminderModel>>(
        stream: controller.getUserReminders(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No reminders found.'));
          }

          final reminders = snapshot.data!;

          /// ✅ 完整依靠 status
          final activeReminders = reminders
              .where((r) => r.status == 'active')
              .toList();

          final expiredReminders = reminders
              .where((r) => r.status == 'expired')
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Active Reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (activeReminders.isEmpty)
                  const Text('No active reminders.')
                else
                  ...activeReminders.map((r) => ReminderCard(reminder: r)),

                const SizedBox(height: 24),
                const Text('Expired Reminders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (expiredReminders.isEmpty)
                  const Text('No expired reminders.')
                else
                  ...expiredReminders.map((r) => ReminderCard(reminder: r)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class ReminderCard extends StatelessWidget {
  final MaintenanceReminderModel reminder;

  const ReminderCard({super.key, required this.reminder});

  @override
  Widget build(BuildContext context) {
    final localDueDate = reminder.dueDateTime.toLocal(); // ⭐ 自动转马来西亚时间
    final dueDateStr = DateFormat('yyyy-MM-dd HH:mm').format(localDueDate);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        title: Text(reminder.maintenanceType),
        subtitle: Text('Due: $dueDateStr'),
        trailing: Text(
          reminder.status == 'active' ? 'Active' : 'Expired',
          style: TextStyle(
            color: reminder.status == 'active' ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
