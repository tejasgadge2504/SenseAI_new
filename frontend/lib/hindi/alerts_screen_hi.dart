import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../models/diagnosis_record.dart';
import '../../services/storage_service.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../theme.dart';

class _PatientAlert {
  final Patient patient;
  final List<_DiagnosisAlert> diagnosisAlerts;
  _PatientAlert({required this.patient, required this.diagnosisAlerts});

  int get totalPending =>
      diagnosisAlerts.fold(0, (s, d) => s + d.pendingItems.length);
}

class _DiagnosisAlert {
  final DiagnosisRecord record;
  final List<String> pendingItems;
  _DiagnosisAlert({required this.record, required this.pendingItems});
}

class AlertsScreenHi extends StatefulWidget {
  const AlertsScreenHi({super.key});

  @override
  State<AlertsScreenHi> createState() => _AlertsScreenHiState();
}

class _AlertsScreenHiState extends State<AlertsScreenHi> {
  List<_PatientAlert> _alerts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final patients = await StorageService.getPatients();
    final List<_PatientAlert> alertList = [];

    for (final p in patients) {
      final records = await StorageService.getDiagnosesForPatient(p.id);
      final diagAlerts = <_DiagnosisAlert>[];

      for (final r in records) {
        if (r.checklist.isEmpty) continue;
        final pending = <String>[];
        for (int i = 0; i < r.checklist.length; i++) {
          if (!r.checkedActions.contains(i)) {
            pending.add(r.checklist[i]);
          }
        }
        if (pending.isNotEmpty) {
          diagAlerts.add(_DiagnosisAlert(record: r, pendingItems: pending));
        }
      }

      if (diagAlerts.isNotEmpty) {
        alertList.add(_PatientAlert(patient: p, diagnosisAlerts: diagAlerts));
      }
    }

    if (mounted) setState(() { _alerts = alertList; _loading = false; });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final m = ['जन', 'फर', 'मार', 'अप्र', 'मई', 'जून', 'जुल', 'अग', 'सित', 'अक्ट', 'नव', 'दिस'];
      return '${dt.day} ${m[dt.month-1]} ${dt.year}';
    } catch (_) { return iso; }
  }

  Color _riskColor(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':   return const Color(0xFFC0392B);
      case 'MEDIUM': return AppColors.amber;
      case 'LOW':    return AppColors.darkGreen;
      default:       return AppColors.textLight;
    }
  }

  String _riskLabel(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':   return 'उच्च';
      case 'MEDIUM': return 'मध्यम';
      case 'LOW':    return 'कम';
      default:       return level;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const RuraxTopBar(title: 'अलर्ट', showBack: true),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.darkGreen))
                  : _alerts.isEmpty
                  ? _emptyState()
                  : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.darkGreen,
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    _summaryBanner(),
                    const SizedBox(height: 16),
                    ..._alerts.map((a) => _patientAlertCard(a)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RuraxBottomNav(
        selectedIndex: 3,
        onTap: (i) { if (i == 0) Navigator.popUntil(context, (r) => r.isFirst); },
      ),
    );
  }

  Widget _summaryBanner() {
    final totalPatients = _alerts.length;
    final totalPending = _alerts.fold(0, (s, a) => s + a.totalPending);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: AppColors.amber.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.amber.withOpacity(0.3))),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
              color: AppColors.amber.withOpacity(0.2), shape: BoxShape.circle),
          child: const Icon(Icons.notifications_active_outlined,
              color: AppColors.amber, size: 22),
        ),
        const SizedBox(width: 14),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$totalPending लंबित कार्य',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                  color: AppColors.textDark)),
          Text('$totalPatients मरीज़ ${totalPatients == 1 ? '' : 'ों'} में',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
        ]),
      ]),
    );
  }

  Widget _patientAlertCard(_PatientAlert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
                color: AppColors.darkGreen.withOpacity(0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.darkGreen.withOpacity(0.15),
                child: Text(
                  alert.patient.name.isNotEmpty ? alert.patient.name[0].toUpperCase() : '?',
                  style: const TextStyle(color: AppColors.darkGreen,
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(alert.patient.name, style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  Text('आयु ${alert.patient.age}  •  ${alert.patient.gender}',
                      style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: AppColors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20)),
                child: Text('${alert.totalPending} बाकी',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.amber)),
              ),
            ]),
          ),
          ...alert.diagnosisAlerts.map((d) => _diagnosisAlertSection(d)),
        ],
      ),
    );
  }

  Widget _diagnosisAlertSection(_DiagnosisAlert d) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _riskColor(d.record.riskLevel).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8)),
              child: Text(d.record.diseaseType,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                      color: _riskColor(d.record.riskLevel))),
            ),
            const SizedBox(width: 8),
            Text(_formatDate(d.record.timestamp),
                style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
            const Spacer(),
            Text('${d.pendingItems.length} बाकी',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: AppColors.textLight)),
          ]),
          const SizedBox(height: 8),
          ...d.pendingItems.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 18, height: 18,
                decoration: BoxDecoration(
                    border: Border.all(color: AppColors.amber, width: 1.5),
                    borderRadius: BorderRadius.circular(4)),
                child: const Icon(Icons.warning_amber_rounded,
                    color: AppColors.amber, size: 12),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item, style: const TextStyle(fontSize: 13,
                    color: AppColors.textMid, height: 1.4)),
              ),
            ]),
          )),
          const SizedBox(height: 4),
          const Divider(color: AppColors.divider),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
              color: AppColors.darkGreen.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline,
              color: AppColors.darkGreen, size: 40),
        ),
        const SizedBox(height: 16),
        const Text('सब ठीक है!', style: TextStyle(fontSize: 18,
            fontWeight: FontWeight.w700, color: AppColors.textDark)),
        const SizedBox(height: 6),
        const Text('कोई लंबित चेकलिस्ट कार्य नहीं।',
            style: TextStyle(fontSize: 13, color: AppColors.textLight)),
        const SizedBox(height: 4),
        const Text('मरीज़ देखभाल में बेहतरीन काम जारी रखें।',
            style: TextStyle(fontSize: 13, color: AppColors.textLight)),
      ]),
    );
  }
}