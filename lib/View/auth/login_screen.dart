import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ridefix/HomePage.dart';
import 'package:ridefix/View/maintenance/maintenance_main_view.dart';
import 'package:ridefix/View/profile/profile_screen.dart';
import 'package:ridefix/View/troubleshoot/qna_list_view.dart';
import 'package:ridefix/View/troubleshoot/troubleshooting_page.dart';
import '/widgets/custom_textfield.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      final user = FirebaseAuth.instance.currentUser!;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Login successful!')));

      // ✅ Navigate to GuideScreen after successful login
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => HomePage(userDoc: userDoc)),
      );
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed';
      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'Wrong password provided.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format.';
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorMessage)));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icons/ridefx_logo.png', height: 100),
                  const SizedBox(height: 16),
                  const Text(
                    "Welcome Back to RideFX",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Login to your account!",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),

                  // 🔹 Email
                  CustomTextField(
                    controller: _emailController,
                    hintText: "Email",
                    icon: Icons.email_outlined,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter your email";
                      } else if (!value.contains('@')) {
                        return "Enter a valid email";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // 🔹 Password
                  CustomTextField(
                    controller: _passwordController,
                    hintText: "Password",
                    icon: Icons.lock_outline,
                    obscureText: _obscurePassword,
                    suffixIcon: _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    onSuffixIconTap: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter your password";
                      }
                      return null;
                    },
                  ),

                  // 🔹 Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Forgot Password?",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 🔹 Login Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 60,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text("Login", style: TextStyle(fontSize: 16)),
                  ),

                  const SizedBox(height: 16),

                  // 🔹 Sign Up
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don’t have an account? "),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const RegisterScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          "Sign up",
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
