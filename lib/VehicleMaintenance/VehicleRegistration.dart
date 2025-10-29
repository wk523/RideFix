import 'package:flutter/material.dart';

// --- Vehicle Registration Page Widget ---
class VehicleRegistrationPage extends StatelessWidget {
  const VehicleRegistrationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],

      // Blue AppBar
      appBar: AppBar(
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            /* Handle back navigation */
          },
        ),
        title: const Text(
          'Vehicle Registration',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: ListView(
        // Increased top padding from 20.0 to 30.0 for better spacing
        padding: const EdgeInsets.fromLTRB(20.0, 50.0, 20.0, 20.0),
        children: [
          // --- 1. Vehicle Image Input Area --- (Now has more space above it)
          Center(
            child: GestureDetector(
              onTap: () {
                /* Handle image picking */
              },
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.camera_alt,
                  color: Colors.grey.shade600,
                  size: 40,
                ),
              ),
            ),
          ),

          // Reduced the SizedBox here since we added padding above
          const SizedBox(height: 40.0),

          // --- 2. Input Fields Container ---
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                ),
              ],
            ),
            child: Column(
              children: [
                // Brand and Model
                Row(
                  children: [
                    Expanded(child: _buildInputField(hintText: 'Brand')),
                    const SizedBox(width: 10),
                    Expanded(child: _buildInputField(hintText: 'Model')),
                  ],
                ),
                const SizedBox(height: 10),

                // Remaining Fields
                _buildInputField(hintText: 'Vehicle Plate Number'),
                const SizedBox(height: 10),
                _buildInputField(hintText: 'Color'),
                const SizedBox(height: 10),
                _buildInputField(
                  hintText: 'Manufacture Year',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _buildInputField(
                  hintText: 'Mileage',
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                _buildInputField(hintText: 'Road Tax Expired Date'),
                const SizedBox(height: 30),

                // --- 3. Register Button ---
                Padding(
                  // Applying horizontal padding (e.g., 50.0 on each side)
                  padding: const EdgeInsets.symmetric(horizontal: 50.0),
                  child: SizedBox(
                    // Set width to infinity *within this padding*
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Handle registration submission
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        // Shorter height
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        // More rounded corners
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25.0),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Register',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper function for the compact text fields
  Widget _buildInputField({
    required String hintText,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(5.0),
      ),
      child: TextField(
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey.shade500),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12.0,
            vertical: -4,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }
}
