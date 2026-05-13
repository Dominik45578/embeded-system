import 'package:flutter/material.dart';

class CustomCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final String? title;

  const CustomCard({
    super.key,
    required this.child,
    this.padding,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF2C2C2E),
          width: 1,
        ),
      ),
      child: title == null
          ? child
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title!,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}