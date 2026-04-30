import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../models/diagnosis_record.dart';
import '../../services/storage_service.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/risk_badge.dart';
import '../../theme.dart';

class PatientHistoryScreenHi extends StatefulWidget {
  const PatientHistoryScreenHi({super.key});

  @override
  State<PatientHistoryScreenHi> createState() => _PatientHistoryScreenHiState();
}

class _PatientHistoryScreenHiState extends State<PatientHistoryScreenHi> {
  List<Patient> _patients = [];
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final patients = await StorageService.getPatients();
    if (mounted) setState(() {
      _patients = patients;
      _loading = false;
    });
  }

  List<Patient> get _filtered {
    if (_search.isEmpty) return _patients;
    return _patients
        .where((p) => p.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const RuraxTopBar(title: 'मरीज़ इतिहास', showBack: true),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textDark),
                        decoration: const InputDecoration(
                          hintText: 'मरीज़ खोजें...',
                          prefixIcon: Icon(Icons.search,
                              color: AppColors.textHint, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.darkGreen))
                        : _filtered.isEmpty
                        ? _emptyState()
                        : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.darkGreen,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) => _patientCard(_filtered[i]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RuraxBottomNav(
        selectedIndex: 2,
        onTap: (i) {
          if (i == 0) Navigator.popUntil(context, (r) => r.isFirst);
        },
      ),
    );
  }

  Widget _patientCard(Patient p) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PatientDetailScreenHi(patient: p))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.darkGreen.withOpacity(0.12),
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.darkGreen,
                    fontWeight: FontWeight.w700,
                    fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text('आयु ${p.age}  •  ${p.gender}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 70, height: 70,
            decoration: BoxDecoration(
                color: AppColors.darkGreen.withOpacity(0.08), shape: BoxShape.circle),
            child: const Icon(Icons.people_outline, color: AppColors.darkGreen, size: 34),
          ),
          const SizedBox(height: 16),
          const Text('कोई मरीज़ नहीं मिला',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark)),
          const SizedBox(height: 6),
          const Text('होम स्क्रीन से मरीज़ पंजीकृत करें।',
              style: TextStyle(fontSize: 13, color: AppColors.textLight)),
        ],
      ),
    );
  }
}

class PatientDetailScreenHi extends StatefulWidget {
  final Patient patient;
  const PatientDetailScreenHi({super.key, required this.patient});

  @override
  State<PatientDetailScreenHi> createState() => _PatientDetailScreenHiState();
}

class _PatientDetailScreenHiState extends State<PatientDetailScreenHi> {
  List<DiagnosisRecord> _records = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final records = await StorageService.getDiagnosesForPatient(widget.patient.id);
    if (mounted) setState(() { _records = records; _loading = false; });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final months = ['जन', 'फर', 'मार', 'अप्र', 'मई', 'जून', 'जुल', 'अग', 'सित', 'अक्ट', 'नव', 'दिस'];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            RuraxTopBar(title: p.name, showBack: true, onBack: () => Navigator.pop(context)),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                          color: AppColors.darkGreen,
                          borderRadius: BorderRadius.circular(18)),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            child: Text(
                              p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: const TextStyle(
                                    color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text('आयु ${p.age}  •  ${p.gender}',
                                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                if (p.phone != null && p.phone!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    const Icon(Icons.phone, color: Colors.white54, size: 13),
                                    const SizedBox(width: 4),
                                    Text(p.phone!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                                  ]),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('जांच इतिहास',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: AppColors.textLight, letterSpacing: 1.2)),
                    const SizedBox(height: 12),
                    if (_loading)
                      const Center(child: CircularProgressIndicator(color: AppColors.darkGreen))
                    else if (_records.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: AppColors.textHint),
                            SizedBox(width: 10),
                            Text('अभी तक कोई जांच दर्ज नहीं।',
                                style: TextStyle(color: AppColors.textMid, fontSize: 14)),
                          ],
                        ),
                      )
                    else
                      ..._records.map((r) => _diagnosisCard(r)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagnosisCard(DiagnosisRecord r) {
    return GestureDetector(
      onTap: () => _showDetail(r),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(r.diseaseType, style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                ),
                RiskBadge(level: r.riskLevel, score: r.riskScore),
              ],
            ),
            const SizedBox(height: 4),
            Text(_formatDate(r.timestamp),
                style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
            if (r.recommendation.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                r.recommendation.length > 120
                    ? '${r.recommendation.substring(0, 120)}...'
                    : r.recommendation,
                style: const TextStyle(fontSize: 13, color: AppColors.textMid, height: 1.4),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (r.checklist.isNotEmpty)
                  Text(
                    '${r.checkedActions.length}/${r.checklist.length} कार्य पूर्ण',
                    style: TextStyle(
                        fontSize: 12,
                        color: r.checkedActions.length == r.checklist.length
                            ? AppColors.darkGreen
                            : AppColors.textLight,
                        fontWeight: FontWeight.w500),
                  )
                else
                  const SizedBox.shrink(),
                const Row(children: [
                  Text('विवरण देखें',
                      style: TextStyle(fontSize: 12, color: AppColors.darkGreen,
                          fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.darkGreen),
                ]),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(DiagnosisRecord r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (_, ctrl) => SingleChildScrollView(
          controller: ctrl,
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(r.diseaseType,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
              const SizedBox(height: 4),
              Text(_formatDate(r.timestamp),
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              const SizedBox(height: 12),
              RiskBadge(level: r.riskLevel, score: r.riskScore),
              const SizedBox(height: 16),
              _detailSection('विवरण', (r.apiResponse['explanation'] ?? '').toString()),
              _detailSection('सिफारिश', r.recommendation),
              if (r.checklist.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('कार्य सूची',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.textLight, letterSpacing: 1.1)),
                const SizedBox(height: 8),
                ...List.generate(r.checklist.length, (i) {
                  final ticked = r.checkedActions.contains(i);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Icon(
                        ticked ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 16,
                        color: ticked ? AppColors.darkGreen : AppColors.textHint,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(r.checklist[i],
                            style: TextStyle(fontSize: 13, height: 1.4,
                                color: ticked ? AppColors.darkGreen : AppColors.textMid,
                                fontWeight: ticked ? FontWeight.w600 : FontWeight.normal)),
                      ),
                    ]),
                  );
                }),
                if (r.checkedActions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${r.checklist.length} में से ${r.checkedActions.length} कार्य पूर्ण',
                      style: const TextStyle(fontSize: 12, color: AppColors.darkGreen,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailSection(String title, String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textLight, letterSpacing: 1.1)),
          const SizedBox(height: 6),
          Text(content, style: const TextStyle(fontSize: 13, color: AppColors.textMid, height: 1.5)),
        ],
      ),
    );
  }
}