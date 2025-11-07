import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ridefix/Expenses&Analytics/ExpensesAnalytics.dart';
import 'package:ridefix/HomePage.dart';
import 'package:ridefix/ServiceRecord/AddServiceRecord.dart';
import 'package:ridefix/ServiceRecord/ServiceRecord.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ridefix/VehicleMaintenance/VehicleList.dart';

const supabaseUrl = 'https://jxcmwksfbyqeiyrxcada.supabase.co';
const supabaseKey =
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp4Y213a3NmYnlxZWl5cnhjYWRhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE3MzczMDQsImV4cCI6MjA3NzMxMzMwNH0.UlQkbjiVNOlb1SfqPBYUdOntkuRLbyIl_EELaw3McmY";

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseKey);
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

      // home: AddServiceRecordPage(),
      home: CarCareApp(),
      debugShowCheckedModeBanner: false, // Optional: Removes the debug banner
    );
  }
}

// NOTE: Ensure your 'vehiclelist.dart' file contains the
// VehicleListScreen, Vehicle, and mockVehicles classes.
