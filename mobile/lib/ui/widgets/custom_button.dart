import 'package:flutter/material.dart';

enum CustomButtonType { primary, secondary, danger }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final CustomButtonType type;
  final IconData? icon;
  final bool isFullWidth;

  const CustomButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.type = CustomButtonType.primary,
    this.icon,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    Color getBackgroundColor() {
      switch (type) {
        case CustomButtonType.primary:
          return const Color(0xFF00ADB5);
        case CustomButtonType.secondary:
          return const Color(0xFF2C2C2E);
        case CustomButtonType.danger:
          return const Color(0xFFFF453A);
      }
    }

    Color getForegroundColor() {
      switch (type) {
        case CustomButtonType.primary:
          return const Color(0xFF121212);
        case CustomButtonType.secondary:
        case CustomButtonType.danger:
          return Colors.white;
      }
    }

    final buttonStyle = FilledButton.styleFrom(
      backgroundColor: getBackgroundColor(),
      foregroundColor: getForegroundColor(),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 0,
    );

    Widget buttonContent = Row(
      mainAxisSize: isFullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
        ],
        Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );

    return isFullWidth
        ? SizedBox(width: double.infinity, child: FilledButton(style: buttonStyle, onPressed: onPressed, child: buttonContent))
        : FilledButton(style: buttonStyle, onPressed: onPressed, child: buttonContent);
  }
}
