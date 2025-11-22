import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:ridefix/services/notification_service.dart';

// Import your app screens
import 'View/auth/welcome_screen.dart';
import 'View/auth/login_screen.dart';
import 'View/auth/register_screen.dart';
import 'View/profile/profile_screen.dart';
import 'VehicleMaintenance/VehicleList.dart';
import 'VehicleMaintenance/VehicleRegistration.dart';
import 'VehicleMaintenance/UpdateVehicle.dart';
import 'View/troubleshoot/troubleshooting_page.dart';
import 'view/troubleshoot/qna_list_view.dart';
import 'View/maintenance/maintenance_main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // 1️⃣ Initialize Firebase first
    await Firebase.initializeApp();
    print('✅ Firebase initialized successfully');

    // 2️⃣ Initialize NotificationService AFTER Firebase
    await NotificationService().initialize();
    print('✅ NotificationService initialized successfully');
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
        '/register': (context) => const RegisterScreen(),
        '/vehicleList': (context) => VehicleListPage(),
        '/vehicleRegister': (context) => VehicleRegistrationPage(),
        '/updateVehicle': (context) => UpdateVehiclePage(),
        '/profile': (context) => const ProfileScreen(),
        '/guide': (context) => const TroubleshootingPage(),
        '/qnaList': (context) => QnaListView(),
        '/maintenance': (context) => MaintenanceMainView(),
      },
    );
  }
}
