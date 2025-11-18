import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ridefix/Controller/Vehicle/VehicleMaintenanceDatabase.dart';
import 'package:ridefix/HomePage.dart';
import 'package:ridefix/Services/notification_service.dart';
import 'package:ridefix/View/Fuel&MileageAnalytics/AddFuelEntry.dart';
import 'package:ridefix/View/auth/register_screen.dart';

// Import RideFX onboarding and login pages
import 'View/auth/welcome_screen.dart';
import 'package:ridefix/view/auth/login_screen.dart';
import 'package:ridefix/view/profile/profile_screen.dart';

// Import vehicle maintenance modules
import 'package:ridefix/View/VehicleMaintenance/UpdateVehicle.dart';
import 'package:ridefix/View/VehicleMaintenance/VehicleDetails.dart';
import 'package:ridefix/View/VehicleMaintenance/VehicleList.dart';
import 'package:ridefix/View/VehicleMaintenance/VehicleRegistration.dart';

//Import troubleshooting
import 'package:ridefix/View/troubleshoot/troubleshooting_page.dart';
import 'package:ridefix/view/troubleshoot/qna_list_view.dart';

//Import Maintenance Reminder
import 'package:ridefix/View/maintenance/maintenance_main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase FIRST (must)
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');

    // Initialize notification AFTER Firebase
    await NotificationService().initialize();
    print('✅ Notification service initialized successfully');
  } catch (e) {
    print('❌ Error during initialization: $e');
  }

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
        // '/home': (context) => const HomePage(),
        '/profile': (context) => const ProfileScreen(),
        '/guide': (context) => const TroubleshootingPage(),
        '/register': (context) => const RegisterScreen(),
        '/qnaList': (context) => QnaListView(),
        '/maintenance': (context) => MaintenanceMainView(),
      },
    );
  }
}
