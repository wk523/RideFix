import 'package:flutter/material.dart';
import 'package:ridefix/View/parking/parking_tracker_view.dart';
import 'package:ridefix/View/parking/edit_active_parking_page.dart';

class ParkingMainPage extends StatelessWidget {
  const ParkingMainPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parking Assistant'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // -----------------------------
            // Save New Parking
            // -----------------------------
            _buildMenuButton(
              context,
              icon: Icons.add_location_alt,
              label: 'Save New Parking',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                    const ParkingTrackerPage(showAddForm: true),
                  ),
                );
              },
            ),

            const SizedBox(height: 20),

            // -----------------------------
            // Edit Active Parking Reminder
            // -----------------------------
            _buildMenuButton(
              context,
              icon: Icons.edit_location_alt,
              label: 'Edit Active Parking',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const EditActiveParkingPage(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context, {
        required IconData icon,
        required String label,
        required VoidCallback onPressed,
      }) {
    return ElevatedButton.icon(
      icon: Icon(icon, size: 28),
      label: Text(label),
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
