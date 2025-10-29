import 'package:flutter/material.dart';
import 'package:ridefix/VehicleMaintenance/UpdateVehicle.dart';
import 'package:ridefix/VehicleMaintenance/VehicleDetails.dart';
import 'package:ridefix/VehicleMaintenance/VehicleList.dart';
import 'package:ridefix/VehicleMaintenance/VehicleRegistration.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // The "Vehicle List" title that appears in the app switcher
      title: 'FYP Vehicle App',

      // Define the primary theme color
      theme: ThemeData(
        // Set the primary color to a shade of blue for the App Bar
        primarySwatch: Colors.blue,
        // This makes the AppBar look exactly like the screenshot's header
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          elevation: 0,
        ),
        // Set a light grey background to mimic the screenshot's surrounding color
        scaffoldBackgroundColor: Colors.grey[200],
        useMaterial3: true,
      ),

      // Set the VehicleListScreen as the home screen
      home: VehicleDetailsPage(details: mockDetails),
      // home: UpdateVehiclePage(),
      debugShowCheckedModeBanner: false, // Optional: Removes the debug banner
    );
  }
}

// NOTE: Ensure your 'vehiclelist.dart' file contains the
// VehicleListScreen, Vehicle, and mockVehicles classes.
