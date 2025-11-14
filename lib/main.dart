import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ridefix/View/auth/register_screen.dart';
import 'package:ridefix/services/notification_service.dart';

// Import RideFX onboarding and login pages
import 'View/auth/welcome_screen.dart';
import 'package:ridefix/view/auth/login_screen.dart';
import 'package:ridefix/view/profile/profile_screen.dart';

// Import vehicle maintenance modules
import 'package:ridefix/VehicleMaintenance/UpdateVehicle.dart';
import 'package:ridefix/VehicleMaintenance/VehicleDetails.dart';
import 'package:ridefix/VehicleMaintenance/VehicleList.dart';
import 'package:ridefix/VehicleMaintenance/VehicleRegistration.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideFX App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.blue,
          elevation: 0,
        ),
        useMaterial3: true,
      ),

      // Set the VehicleListScreen as the home screen
      // home: VehicleDetailsPage(details: mockDetails),
      home: VehicleListPage(),
      debugShowCheckedModeBanner: false, // Optional: Removes the debug banner
    );
  }
}

// NOTE: Ensure your 'vehiclelist.dart' file contains the
// VehicleListScreen, Vehicle, and mockVehicles classes.
