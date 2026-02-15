import 'package:flutter/material.dart';

class InputField extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final IconData? icon;
  final bool isPassword;
  final VoidCallback? onSubmitted;
  final Color? fillColor;
  final double borderRadius;
  final EdgeInsets contentPadding;

  const InputField({
    super.key,
    required this.hintText,
    required this.controller,
    this.icon,
    this.isPassword = false,
    this.onSubmitted,
    this.fillColor,
    this.borderRadius = 14,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 12,
    ),
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      onSubmitted: (_) => onSubmitted?.call(),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Theme.of(context).hintColor,
        ),
        filled: true,
        fillColor: fillColor ??
            (isDark ? Colors.white.withOpacity(0.08) : Colors.grey[200]),
        prefixIcon: icon != null ? Icon(icon, color: Colors.deepPurple) : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        contentPadding: contentPadding,
      ),
    );
  }
}
