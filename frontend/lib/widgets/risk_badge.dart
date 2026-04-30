import 'package:flutter/material.dart';
import '../theme.dart';

class RiskBadge extends StatelessWidget {
  final String level;
  final int? score;

  const RiskBadge({super.key, required this.level, this.score});

  Color get _color {
    switch (level.toUpperCase()) {
      case 'CRITICAL':
      case 'HIGH':
        return AppColors.riskHigh;
      case 'MEDIUM':
        return AppColors.riskMed;
      default:
        return AppColors.riskLow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, color: _color, size: 18),
          const SizedBox(width: 6),
          Text(
            level.toUpperCase(),
            style: TextStyle(
              color: _color,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.5,
            ),
          ),
          if (score != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$score',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ],
      ),
    );
  }
}