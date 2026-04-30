import 'package:flutter/material.dart';
import '../widgets/top_bar.dart';
import '../widgets/bottom_nav.dart';
import '../theme.dart';

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            RuraxTopBar(title: title, showBack: true),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.darkGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.construction_outlined,
                          color: AppColors.darkGreen, size: 38),
                    ),
                    const SizedBox(height: 20),
                    const Text('Coming Soon',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark)),
                    const SizedBox(height: 8),
                    const Text(
                      'This screen is under development.',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, size: 18),
                      label: const Text('Go Back'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 28, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RuraxBottomNav(
        selectedIndex: 0,
        onTap: (i) {
          if (i == 0) Navigator.popUntil(context, (r) => r.isFirst);
        },
      ),
    );
  }
}