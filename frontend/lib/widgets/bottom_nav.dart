import 'package:flutter/material.dart';
import '../theme.dart';

class RuraxBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const RuraxBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  static const _items = [
    {'icon': Icons.home_outlined, 'label': 'HOME'},
    {'icon': Icons.add_circle_outline, 'label': 'NEW'},
    {'icon': Icons.history, 'label': 'HISTORY'},
    {'icon': Icons.notifications_outlined, 'label': 'ALERTS'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
        Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_items.length, (i) {
              final sel = selectedIndex == i;
              return GestureDetector(
                onTap: () => onTap(i),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _items[i]['icon'] as IconData,
                      color: sel
                          ? AppColors.darkGreen
                          : AppColors.textHint,
                      size: 22,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _items[i]['label'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight:
                        sel ? FontWeight.w700 : FontWeight.w400,
                        color: sel
                            ? AppColors.darkGreen
                            : AppColors.textHint,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}