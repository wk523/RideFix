import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixIconTap; // 👈 for eye icon tap
  final String? Function(String?)? validator; // 👈 for form validation

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator, // 👈 enables validation in forms
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon != null
            ? GestureDetector(
          onTap: onSuffixIconTap, // 👈 makes the eye icon clickable
          child: Icon(suffixIcon),
        )
            : null,
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
