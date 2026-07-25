import 'package:flutter/material.dart';

/// Compact status badge chip
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const StatusBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor = Colors.white,
  });

  factory StatusBadge.fromStatus(String status) {
    switch (status) {
      case 'publish':
        return StatusBadge(label: 'प्रकाशित', color: const Color(0xFF1B873F));
      case 'draft':
        return StatusBadge(label: 'मसुदा', color: const Color(0xFF4B5563), textColor: Colors.white);
      case 'future':
        return StatusBadge(label: 'नियोजित', color: const Color(0xFFB45309));
      case 'private':
        return StatusBadge(label: 'खासगी', color: const Color(0xFF7C3AED));
      case 'trash':
        return StatusBadge(label: 'हटविले', color: const Color(0xFFBA1A1A));
      default:
        return StatusBadge(label: status, color: const Color(0xFF4B5563));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
