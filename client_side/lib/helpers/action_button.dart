import 'package:flutter/material.dart';

class ActionButton extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final bool isSecondary;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;

  const ActionButton({
    super.key,
    required this.text,
    this.icon,
    required this.color,
    this.isSecondary = false,
    this.onPressed,
    this.isLoading = false,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width ?? double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : (icon != null
                ? Icon(icon, color: Colors.white)
                : const SizedBox.shrink()),
        label: Text(
          isLoading ? 'Please wait...' : text,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isSecondary ? color.withOpacity(0.8) : color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
        ),
      ),
    );
  }
}
