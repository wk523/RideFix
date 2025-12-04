import 'package:flutter/material.dart';
import 'package:ridefix/View/ExpensesAnalytics/ExpensesAnalytics.dart';
import 'package:ridefix/View/Fuel&MileageAnalytics/FuelAnalytics.dart';
import 'package:ridefix/View/Fuel&MileageAnalytics/FuelEntry.dart';
import 'package:ridefix/View/RoadsideEmergency/EmergencyService.dart';
import 'package:ridefix/View/ServiceRecord/ServiceRecord.dart';
import 'package:ridefix/View/VehicleMaintenance/VehicleList.dart';
import 'package:ridefix/View/maintenance/maintenance_main_view.dart';
import 'package:ridefix/View/parking/parking_main_page.dart';
import 'package:ridefix/View/profile/profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:ridefix/View/troubleshoot/troubleshooting_page.dart';
import 'package:ridefix/View/workshop/workshop_locator_page.dart';
import '../../Controller/EmergencyService/EmergencyServiceController.dart';
import 'Controller/ExpensesAnalytics/ExpensesAnalyticsConrtoller.dart';

class HomePage extends StatelessWidget {
  final DocumentSnapshot userDoc;
  const HomePage({super.key, required this.userDoc});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideFix',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
        useMaterial3: true,
      ),
      home: DashboardScreen(userDoc: userDoc),
    );
  }
}

// --- 1. Dashboard Data Models ---

class Reminder {
  final String type;
  final String category;
  final String date;
  final String time;
  final String status;

  Reminder(this.type, this.category, this.date, this.time, this.status);
}

class Expense {
  final String category;
  final double amount;
  final Color color;

  Expense(this.category, this.amount, this.color);
}

final List<Reminder> reminders = [
  Reminder('Oil Change', 'Maintenance', 'Oct 24, 2025', '10:47', 'Due Soon'),
  Reminder('Road Tax Renewal', 'Road Tax', 'Nov 06, 2025', '10:47', 'Upcoming'),
  Reminder('Tire Rotation', 'Maintenance', 'Oct 20, 2025', '10:47', 'Overdue'),
];

// Removed hardcoded expenses list and totalExpenseAmount
// This data will now be fetched dynamically by ThisMonthExpenseOverview

// --- 2. Custom Widgets for Dashboard ---

class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReminderItem extends StatelessWidget {
  final Reminder reminder;

  const ReminderItem({super.key, required this.reminder});

  Color getStatusColor(String status) {
    switch (status) {
      case 'Overdue':
        return Colors.red;
      case 'Due Soon':
        return Colors.orange;
      case 'Upcoming':
      default:
        return Colors.grey.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = getStatusColor(reminder.status);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reminder.type,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                reminder.category,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                '${reminder.date} • ${reminder.time}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: statusColor, width: 0.5),
            ),
            child: Text(
              reminder.status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ExpenseBar extends StatelessWidget {
  final Expense expense;
  final double totalAmount;

  const ExpenseBar({
    super.key,
    required this.expense,
    required this.totalAmount,
  });

  @override
  Widget build(BuildContext context) {
    // Avoid division by zero
    final double percentage = totalAmount > 0 ? expense.amount / totalAmount : 0;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              expense.category,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            Text(
              'RM ${expense.amount.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade200,
            color: expense.color,
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8), // Added spacing between bars
      ],
    );
  }
}

// --- New Widget for Dynamic Expense Overview ---

class ThisMonthExpenseOverview extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const ThisMonthExpenseOverview({super.key, required this.userDoc});

  @override
  State<ThisMonthExpenseOverview> createState() =>
      _ThisMonthExpenseOverviewState();
}

class _ThisMonthExpenseOverviewState extends State<ThisMonthExpenseOverview> {
  // ⭐️ 1. Instantiate the actual database controller ⭐️
  final _db = ExpensesAnalyticsDatabase();

  double _totalAmount = 0.0;
  List<Expense> _categoryExpenses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchThisMonthExpenses(widget.userDoc.id);
  }

  // ⭐️ 2. Fetch data using the actual controller method ⭐️
  Future<void> _fetchThisMonthExpenses(String userId) async {
    // Current date is the reference date for the current month
    final currentDate = DateTime.now();

    try {
      // Use fetchExpensesByCategory with 'MONTHS' duration to get the current month's totals
      final Map<String, double> fetchedCategoryData =
      await _db.fetchExpensesByCategory(
        uid: userId,
        duration: 'MONTHS', // We want the current month's breakdown
        referenceDate: currentDate,
      );

      final double fetchedTotal = fetchedCategoryData.values.fold(
        0.0,
            (sum, amount) => sum + amount,
      );

      // Convert the fetched Map into a List<Expense>
      final List<Expense> expensesList = fetchedCategoryData.entries.map((entry) {
        // Map category names to colors for the dashboard bars
        Color color = _getColorForCategory(entry.key);
        return Expense(entry.key, entry.value, color);
      }).toList();

      // Sort expenses by amount (highest first)
      expensesList.sort((a, b) => b.amount.compareTo(a.amount));

      if (mounted) {
        setState(() {
          _totalAmount = fetchedTotal;
          _categoryExpenses = expensesList;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard expenses: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ⭐️ 3. Helper function for consistent color mapping ⭐️
  Color _getColorForCategory(String category) {
    // You must match these colors to what you use in ExpensesAnalytics.dart for consistency
    switch (category) {
      case 'Fuel':
        return Colors.blue;
      case 'Maintenance':
        return Colors.red;
      case 'Parking & Toll':
        return Colors.amber;
      case 'Insurance':
        return Colors.green;
      case 'Repair':
        return Colors.purple;
      default:
        return Colors.grey.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading indicator
    if (_isLoading) {
      // ... (Loading UI remains the same)
      return Card(
        margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(
            height: 200,
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      );
    }

    // Show empty state if no data
    if (_categoryExpenses.isEmpty && _totalAmount == 0.0) {
      // ... (Empty state UI remains the same)
      return Card(
        margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 24.0),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Padding(
          padding: EdgeInsets.all(16.0),
          child: SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'No expenses recorded this month.',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ),
      );
    }

    // Build the Card UI with fetched data
    return Card(
      margin: const EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        bottom: 24.0,
      ),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Expense Overview',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Display the correct, fetched total amount
                Text(
                  'RM ${_totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.black87,
                  ),
                ),
                const Spacer(),
                // NOTE: This trend indicator is still static/mocked for now
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.trending_down,
                        size: 14,
                        color: Colors.red.shade700,
                      ),
                      Text(
                        '+12% from last month',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Use the actual fetched category expenses to build the bars
            ..._categoryExpenses.map(
                  (exp) => ExpenseBar(
                expense: exp,
                totalAmount: _totalAmount,
              ),
            ).toList(),
          ],
        ),
      ),
    );
  }
}

// --- 3. Navigation Drawer Widget (Left Panel) ---

class AppDrawer extends StatelessWidget {
  final DocumentSnapshot userDoc;

  const AppDrawer({super.key, required this.userDoc});

  Widget _buildDrawerItem({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    // ... (No change to this helper function)
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: Material(
        color: isSelected ? Colors.blue.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? Colors.blue.shade700 : Colors.black87,
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected ? Colors.blue.shade700 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(String title) {
    // ... (No change)
    return Padding(
      padding: const EdgeInsets.only(left: 20.0, top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade500,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const String currentPage = 'Home';

    return Drawer(
      width: 250,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          // Branding Header (No change)
          Padding(
            padding: const EdgeInsets.only(
              top: 40.0,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.directions_car,
                  size: 32,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RideFix',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    Text(
                      'Vehicle Tracker',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, size: 24, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Main Menu
                _buildHeader('Main Menu'),
                _buildDrawerItem(
                  title: 'Home',
                  icon: Icons.home_outlined,
                  onTap: () => Navigator.pop(context), // Close the drawer
                  isSelected: currentPage == 'Home',
                ),
                _buildDrawerItem(
                  title: 'My Vehicles',
                  icon: Icons.directions_car_outlined,
                  onTap: () {
                    // Close the drawer before navigating
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => VehicleListPage(userDoc: userDoc),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  title: 'Reminders',
                  icon: Icons.access_time,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => MaintenanceMainView(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  title: 'Service Records',
                  icon: Icons.file_copy_outlined,
                  onTap: () {
                    // Close the drawer before navigating
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ServiceRecordPage(userDoc: userDoc),
                      ),
                    );
                  },
                ),

                // Services
                _buildHeader('Services'),
                _buildDrawerItem(
                  title: 'Workshop Locator',
                  icon: Icons.map_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => WorkshopLocatorPage(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  title: 'Troubleshooting',
                  icon: Icons.search,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TroubleshootingPage(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  title: 'Parking Tracker',
                  icon: Icons.local_parking_outlined,
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParkingMainPage(),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  title: 'Fuel Tracking',
                  icon: Icons.local_gas_station_outlined,
                  onTap: () {
                    // Close the drawer before navigating
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FuelEntryPage(userDoc: userDoc),
                      ),
                    );
                  },
                ),

                // Analytics & Help
                _buildHeader('Analytics & Help'),
                _buildDrawerItem(
                  title: 'Expense Analytics',
                  icon: Icons.trending_up,
                  onTap: () {
                    // Close the drawer before navigating
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ExpensesAnalyticsPage(userDoc: userDoc),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  title: 'Fuel Analytics',
                  icon: Icons.trending_up,
                  onTap: () {
                    // Close the drawer before navigating
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            FuelAnalyticsPage(userDoc: userDoc),
                      ),
                    );
                  },
                ),
                _buildDrawerItem(
                  title: 'Emergency Assistance',
                  icon: Icons.help_outline,
                  onTap: () {
                    // Close the drawer before navigating
                    Navigator.pop(context);

                    // 🔥 FIX: Removed the redundant ChangeNotifierProvider wrapper
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EmergencyServicePage(userDoc: userDoc),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // User Profile Footer (No change in navigation logic here, only for profile)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                InkWell(
                  onTap: () {
                    // Close the drawer before navigating
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfileScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Color(0xFFDCEAFB),
                        child: Text(
                          'JD',
                          style: TextStyle(
                            color: Color(0xFF1E40AF),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'John Doe',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          // Text(
                          //   'WXY 1234',
                          //   style: TextStyle(fontSize: 12, color: Colors.grey),
                          // ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(
                    Icons.settings_outlined,
                    size: 24,
                    color: Colors.grey,
                  ),
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// --- 4. Dashboard Screen (Main Content) ---

class DashboardScreen extends StatefulWidget {
  final DocumentSnapshot userDoc;

  const DashboardScreen({super.key, required this.userDoc});

  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  User? user;
  bool loading = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    loadUserData();
  }

  Future<void> loadUserData() async {
    user = _auth.currentUser;

    if (user != null) {
      // The doc is already passed in widget.userDoc, but fetching here for state management context.
      // Keeping this simplified for the dashboard view.
      // final doc = await _firestore.collection('users').doc(user!.uid).get();

      setState(() {
        loading = false;
      });
    }
  }

  Widget _buildSectionHeader(
      String title, {
        String? actionText,
        VoidCallback? onActionTap,
      }) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          if (actionText != null && onActionTap != null)
            TextButton(
              onPressed: onActionTap,
              child: Text(
                actionText,
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.blue,
        surfaceTintColor: Colors.white,
        elevation: 1,
        shadowColor: Colors.black12,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(
              context,
            ).openDrawer(), // This opens the drawer when the icon is clicked
          ),
        ),
        // title: Container(
        //   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        //   decoration: BoxDecoration(
        //     color: Colors.blue.shade50,
        //     borderRadius: BorderRadius.circular(10),
        //   ),
        //   child: const Row(
        //     mainAxisSize: MainAxisSize.min,
        //     // children: [
        //     //   Icon(Icons.directions_car, size: 14, color: Colors.black54),
        //     //   SizedBox(width: 8),
        //     //   Text(
        //     //     'WXY 1234',
        //     //     style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        //     //   ),
        //     //   SizedBox(width: 8),
        //     //   Icon(Icons.arrow_drop_down, size: 14, color: Colors.black54),
        //     // ],
        //   ),
        // ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      drawer: AppDrawer(userDoc: widget.userDoc), // Attach the custom drawer

      body: CustomScrollView(
        slivers: [
          SliverList(
            delegate: SliverChildListDelegate([
              // Dashboard Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Welcome back to RideFix!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Quick Actions Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSectionHeader('Quick Actions'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    QuickActionButton(
                      icon: Icons.phone_enabled_outlined,
                      label: 'Emergency SOS',
                      color: Colors.red.shade500,
                      onTap: () {
                        // 🔥 FIX: Removed the redundant ChangeNotifierProvider wrapper
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                EmergencyServicePage(userDoc: widget.userDoc),
                          ),
                        );
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.access_time,
                      label: 'Maintenance Reminder',
                      color: Colors.blue.shade500,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MaintenanceMainView(),
                          ),
                        );
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.location_on_outlined,
                      label: 'Find Workshop',
                      color: Colors.blue.shade500,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => WorkshopLocatorPage(),
                          ),
                        );
                      },
                    ),
                    QuickActionButton(
                      icon: Icons.add_card_outlined,
                      label: 'Service Record',
                      color: Colors.blue.shade500,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ServiceRecordPage(userDoc: widget.userDoc),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // Upcoming Reminders Section (Initial View)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSectionHeader(
                  'Upcoming Reminders',
                  actionText: 'View All >',
                  onActionTap: () {},
                ),
              ),
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: reminders
                        .map((r) => ReminderItem(reminder: r))
                        .toList(),
                  ),
                ),
              ),

              // This Month/Expense Overview Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildSectionHeader(
                  'This Month',
                  actionText: 'View Analytics >',
                  onActionTap: () {
                    // Navigate to the ExpensesAnalyticsPage
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ExpensesAnalyticsPage(userDoc: widget.userDoc),
                      ),
                    );
                  },
                ),
              ),

              // ⭐️ DYNAMIC EXPENSE OVERVIEW ⭐️
              ThisMonthExpenseOverview(userDoc: widget.userDoc),

              // Added some padding for the bottom of the scroll view
              const SizedBox(height: 16.0),
            ]),
          ),
        ],
      ),
    );
  }
}

// Helper widget for the small action buttons (Find Workshop / Add Service)
Widget _buildSmallActionButton(IconData icon, String label) {
  return Card(
    elevation: 2,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: Colors.blue.shade600),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}