import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

// Import RideFX onboarding and login pages
import 'package:ridefix/screen/auth/welcome_screen.dart';
import 'package:ridefix/screen/auth/login_screen.dart';
import 'package:ridefix/screen/profile/profile_screen.dart';
import 'package:ridefix/screen/auth/register_screen.dart';
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


      home: const WelcomeScreen(),


      routes: {

        '/login': (context) => const LoginScreen(),
        '/vehicleList': (context) => VehicleListPage(),
        '/vehicleRegister': (context) => VehicleRegistrationPage(),
        //'/vehicleDetails': (context) => VehicleDetailsPage(),
        '/updateVehicle': (context) => UpdateVehiclePage(),
        '/profile': (context) =>  ProfileScreen(),
        '/register': (context) => const RegisterScreen(),

      },
    );
  }
}
