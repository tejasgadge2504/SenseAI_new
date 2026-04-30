import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/connectivity_service.dart';
import '../services/storage_service.dart';
import '../services/language_provider.dart';
import '../widgets/top_bar.dart';
import '../widgets/bottom_nav.dart';
import '../theme.dart';
import 'register_patient_screen.dart';
import 'new_diagnosis_screen.dart';
import 'patient_history_screen.dart';
import 'alerts_screen.dart';
import 'reports_screen.dart';
// Hindi screens
import 'package:frontend/hindi//home_screen_hi.dart';
import 'package:frontend/hindi//register_patient_screen_hi.dart';
import 'package:frontend/hindi//new_diagnosis_screen_hi.dart';
import 'package:frontend/hindi//patient_history_screen_hi.dart';
import 'package:frontend/hindi//alerts_screen_hi.dart';
import 'package:frontend/hindi//reports_screen_hi.dart';

/// Root entry point: reads LanguageProvider and delegates to the
/// correct language variant of HomeScreen.
class HomeScreenRouter extends StatelessWidget {
  const HomeScreenRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, lang, _) {
        if (lang.isHindi) return const HomeScreenHi();
        return const HomeScreen();
      },
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _todayCount = 0;
  bool _isOnline = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    ConnectivityService().statusStream.listen((_) {
      if (mounted) setState(() => _isOnline = ConnectivityService().isOnline);
    });
  }

  Future<void> _refresh() async {
    final count = await StorageService.getTodayDiagnosisCount();
    if (mounted) {
      setState(() {
        _todayCount = count;
        _isOnline = ConnectivityService().isOnline;
      });
    }
  }

  void _navigate(int index) {
    final lang = context.read<LanguageProvider>();
    final isHindi = lang.isHindi;

    switch (index) {
      case 0:
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isHindi
                ? const NewDiagnosisScreenHi()
                : const NewDiagnosisScreen(),
          ),
        ).then((_) => _refresh());
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isHindi
                ? const PatientHistoryScreenHi()
                : const PatientHistoryScreen(),
          ),
        );
        break;
      case 3:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isHindi
                ? const AlertsScreenHi()
                : const AlertsScreen(),
          ),
        );
        break;
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => isHindi
                ? const ReportsScreenHi()
                : const ReportsScreen(),
          ),
        );
        break;
    }
  }

  Future<void> _callAgent() async {
    final uri = Uri(scheme: 'tel', path: '+911234567890');
    if (!await launchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showOfflinePopup() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 20),
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.15), shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off, color: AppColors.amber, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('You are offline',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                    color: AppColors.textDark)),
            const SizedBox(height: 8),
            const Text(
              'App works offline. Data will sync when internet returns.\nFor urgent help, call the voice agent:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () { Navigator.pop(context); _callAgent(); },
                icon: const Icon(Icons.phone),
                label: const Text('Call Voice Agent  +91 1234567890'),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final isHindi = lang.isHindi;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const RuraxTopBar(title: 'SenseAI'),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                color: AppColors.darkGreen,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHindi ? 'SenseAI में आपका स्वागत है' : 'Welcome to SenseAI',
                        style: const TextStyle(
                            fontSize: 26, fontWeight: FontWeight.w700,
                            color: AppColors.textDark, letterSpacing: -0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isHindi ? 'ग्रामीण स्वास्थ्य सेवा को सशक्त बनाना' : 'EMPOWERING RURAL HEALTHCARE',
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500,
                            color: AppColors.textLight, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 20),
                      _buildRegisterCard(isHindi),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(child: _buildGridCard(
                            icon: Icons.add_circle_outline,
                            label: isHindi ? 'नई जांच' : 'New Diagnosis',
                            color: AppColors.midGreen,
                            onTap: () => _navigate(1))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildGridCard(
                            icon: Icons.history,
                            label: isHindi ? 'मरीज़ इतिहास' : 'Patient History',
                            color: AppColors.lightGreen,
                            onTap: () => _navigate(2))),
                      ]),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: _buildGridCard(
                            icon: Icons.notifications_outlined,
                            label: isHindi ? 'अलर्ट' : 'Alerts',
                            color: AppColors.darkGreen,
                            onTap: () => _navigate(3))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildGridCard(
                            icon: Icons.description_outlined,
                            label: isHindi ? 'रिपोर्ट' : 'Reports',
                            color: AppColors.amber,
                            onTap: () => _navigate(4))),
                      ]),
                      const SizedBox(height: 20),
                      _buildActivityCard(isHindi),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: !_isOnline
          ? FloatingActionButton(
        onPressed: _showOfflinePopup,
        backgroundColor: AppColors.amber,
        tooltip: isHindi ? 'ऑफ़लाइन - एजेंट को कॉल करें' : 'Offline - Tap to call agent',
        child: const Icon(Icons.phone_in_talk, color: Colors.white),
      )
          : null,
      bottomNavigationBar: RuraxBottomNav(selectedIndex: 0, onTap: _navigate),
    );
  }

  Widget _buildRegisterCard(bool isHindi) {
    final lang = context.read<LanguageProvider>();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => lang.isHindi
              ? const RegisterPatientScreenHi()
              : const RegisterPatientScreen(),
        ),
      ).then((_) => _refresh()),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 32),
        decoration: BoxDecoration(
            color: AppColors.darkGreen, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.12), shape: BoxShape.circle),
            child: const Icon(Icons.person_add_outlined, color: Colors.white, size: 34),
          ),
          const SizedBox(height: 14),
          Text(
            isHindi ? 'मरीज़ पंजीकृत करें' : 'Register Patient',
            style: const TextStyle(color: Colors.white, fontSize: 22,
                fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 4),
          Text(
            isHindi ? 'नया मरीज़ जोड़ें' : 'START PATIENT ONBOARDING',
            style: const TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.4),
          ),
        ]),
      ),
    );
  }

  Widget _buildGridCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 110, padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: Colors.white, size: 26),
            Text(label, style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(bool isHindi) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            isHindi ? 'आज की गतिविधि' : "TODAY'S ACTIVITY",
            style: const TextStyle(fontSize: 10, letterSpacing: 1.2, color: AppColors.textLight),
          ),
          const SizedBox(height: 4),
          Text(
            isHindi
                ? '$_todayCount मरीज़ की जांच'
                : '$_todayCount Patient${_todayCount == 1 ? '' : 's'} Diagnosed',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                color: AppColors.textDark),
          ),
        ]),
        const Spacer(),
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
              color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: const Icon(Icons.trending_up, color: AppColors.darkGreen, size: 22),
        ),
      ]),
    );
  }
}