import 'package:flutter/material.dart';

class ConfidenceBadge extends StatelessWidget {
  final double confidence; // 0.0 - 1.0

  const ConfidenceBadge({super.key, required this.confidence});

  Color _colorFor(double c) {
    if (c >= 0.7) return const Color(0xFF2E7D32);
    if (c >= 0.4) return const Color(0xFFE8A317);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(confidence);
    final percentText = '${(confidence * 100).toStringAsFixed(1)}%';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            'Keyakinan $percentText',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
