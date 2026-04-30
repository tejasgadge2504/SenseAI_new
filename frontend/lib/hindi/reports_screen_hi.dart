import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/patient.dart';
import '../../models/diagnosis_record.dart';
import '../../services/storage_service.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../theme.dart';

class ReportsScreenHi extends StatefulWidget {
  const ReportsScreenHi({super.key});

  @override
  State<ReportsScreenHi> createState() => _ReportsScreenHiState();
}

class _ReportsScreenHiState extends State<ReportsScreenHi> {
  List<Patient> _patients = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final patients = await StorageService.getPatients();
    if (mounted) setState(() { _patients = patients; _loading = false; });
  }

  List<Patient> get _filtered {
    if (_search.isEmpty) return _patients;
    return _patients.where((p) =>
        p.name.toLowerCase().contains(_search.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const RuraxTopBar(title: 'रिपोर्ट', showBack: true),
            Expanded(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Container(
                      decoration: BoxDecoration(
                          color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: TextField(
                        onChanged: (v) => setState(() => _search = v),
                        style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                        decoration: const InputDecoration(
                          hintText: 'मरीज़ खोजें...',
                          prefixIcon: Icon(Icons.search, color: AppColors.textHint, size: 20),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                        itemBuilder: (_, i) => _patientReportCard(_filtered[i]),
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
        selectedIndex: 3,
        onTap: (i) { if (i == 0) Navigator.popUntil(context, (r) => r.isFirst); },
      ),
    );
  }

  Widget _patientReportCard(Patient p) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => PatientReportScreenHi(patient: p))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color: AppColors.darkGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Center(
                child: Text(p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.darkGreen,
                        fontWeight: FontWeight.w700, fontSize: 20)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.name, style: const TextStyle(fontSize: 15,
                    fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text('आयु ${p.age}  •  ${p.gender}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.darkGreen.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.description_outlined, color: AppColors.darkGreen, size: 14),
                SizedBox(width: 4),
                Text('रिपोर्ट', style: TextStyle(fontSize: 12, color: AppColors.darkGreen,
                    fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
              color: AppColors.darkGreen.withOpacity(0.08), shape: BoxShape.circle),
          child: const Icon(Icons.description_outlined, color: AppColors.darkGreen, size: 34),
        ),
        const SizedBox(height: 16),
        const Text('अभी तक कोई रिपोर्ट नहीं', style: TextStyle(fontSize: 16,
            fontWeight: FontWeight.w600, color: AppColors.textDark)),
        const SizedBox(height: 6),
        const Text('पहले मरीज़ पंजीकृत करें और जांच करें।',
            style: TextStyle(fontSize: 13, color: AppColors.textLight)),
      ]),
    );
  }
}

class PatientReportScreenHi extends StatefulWidget {
  final Patient patient;
  const PatientReportScreenHi({super.key, required this.patient});

  @override
  State<PatientReportScreenHi> createState() => _PatientReportScreenHiState();
}

class _PatientReportScreenHiState extends State<PatientReportScreenHi> {
  List<DiagnosisRecord> _records = [];
  bool _loading = true;
  bool _exporting = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final records = await StorageService.getDiagnosesForPatient(widget.patient.id);
    if (mounted) setState(() { _records = records; _loading = false; });
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final m = ['जन', 'फर', 'मार', 'अप्र', 'मई', 'जून', 'जुल', 'अग', 'सित', 'अक्ट', 'नव', 'दिस'];
      return '${dt.day} ${m[dt.month-1]} ${dt.year}';
    } catch (_) { return iso; }
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      final m = ['जन', 'फर', 'मार', 'अप्र', 'मई', 'जून', 'जुल', 'अग', 'सित', 'अक्ट', 'नव', 'दिस'];
      return '${dt.day} ${m[dt.month-1]} ${dt.year}  ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
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

  Future<void> _exportPdf() async {
    if (_records.isEmpty) return;
    setState(() => _exporting = true);
    try {
      final p = widget.patient;
      final doc = pw.Document();
      final totalScore = _records.fold<int>(0, (s, r) => s + r.riskScore);

      doc.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (ctx) => [
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFF2D5016),
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text('चिकित्सा रिपोर्ट',
                        style: pw.TextStyle(color: PdfColors.white,
                            fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 4),
                    pw.Text('RURAX AI द्वारा निर्मित',
                        style: const pw.TextStyle(color: PdfColors.white, fontSize: 10)),
                  ]),
                  pw.Icon(const pw.IconData(0xe873), color: PdfColors.white, size: 32),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            _pdfSection('मरीज़ विवरण', [
              pw.Row(children: [
                _pdfInfoCol('नाम', p.name),
                pw.SizedBox(width: 40),
                _pdfInfoCol('आयु / लिंग', '${p.age} / ${p.gender}'),
              ]),
            ]),
            pw.SizedBox(height: 16),
            _pdfSection('जांच सारांश', [
              ..._records.take(5).map((r) {
                final pct = totalScore > 0 ? ((r.riskScore / totalScore) * 100).round() : 0;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                      pw.Text(r.diseaseType,
                          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                      pw.Text('$pct%', style: const pw.TextStyle(fontSize: 12)),
                    ]),
                    pw.SizedBox(height: 4),
                    pw.LinearProgressIndicator(
                      value: pct / 100,
                      backgroundColor: PdfColors.grey200,
                      valueColor: const PdfColor.fromInt(0xFF2D5016),
                    ),
                  ]),
                );
              }),
            ]),
            pw.SizedBox(height: 16),
            if (_records.isNotEmpty)
              _pdfSection('सिफारिश', [
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                      color: PdfColors.grey100, borderRadius: pw.BorderRadius.circular(8)),
                  child: pw.Text(
                    _records.first.recommendation.isNotEmpty
                        ? _records.first.recommendation
                        : 'कोई सिफारिश उपलब्ध नहीं।',
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  ),
                ),
              ]),
            pw.SizedBox(height: 24),
            pw.Center(
              child: pw.Text(
                'रिपोर्ट ID: ${p.id.substring(0, 8).toUpperCase()}-${DateTime.now().year}',
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500, letterSpacing: 1),
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(onLayout: (fmt) async => doc.save());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('निर्यात विफल: $e'),
          backgroundColor: Colors.redAccent,
        ));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  pw.Widget _pdfSection(String title, List<pw.Widget> children) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Row(children: [
        pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600, letterSpacing: 1.2)),
        pw.SizedBox(width: 8),
        pw.Expanded(child: pw.Divider(color: PdfColors.grey300)),
      ]),
      pw.SizedBox(height: 8),
      ...children,
    ]);
  }

  pw.Widget _pdfInfoCol(String label, String value) {
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey500, letterSpacing: 0.8)),
      pw.SizedBox(height: 2),
      pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.patient;
    final totalScore = _records.fold<int>(0, (s, r) => s + r.riskScore);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            RuraxTopBar(title: 'चिकित्सा रिपोर्ट', showBack: true,
                onBack: () => Navigator.pop(context)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.darkGreen))
                  : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                        color: Colors.white, borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06),
                            blurRadius: 12, offset: const Offset(0, 4))]),
                    child: Column(children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                            color: AppColors.darkGreen,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('चिकित्सा रिपोर्ट', style: TextStyle(color: Colors.white,
                                  fontSize: 22, fontWeight: FontWeight.w700)),
                              SizedBox(height: 2),
                              Text('RURAX AI द्वारा निर्मित', style: TextStyle(
                                  color: Colors.white60, fontSize: 10, letterSpacing: 1.2)),
                            ]),
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.description_outlined, color: Colors.white, size: 24),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _reportSectionLabel('मरीज़ विवरण'),
                          const SizedBox(height: 12),
                          Row(children: [
                            _infoCol('नाम', p.name),
                            const SizedBox(width: 32),
                            _infoCol('आयु / लिंग', '${p.age} / ${p.gender}'),
                          ]),
                          const SizedBox(height: 20),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: 16),
                          _reportSectionLabel('जांच सारांश'),
                          const SizedBox(height: 12),
                          if (_records.isEmpty)
                            const Text('अभी तक कोई जांच नहीं।',
                                style: TextStyle(fontSize: 13, color: AppColors.textLight))
                          else
                            ..._records.take(5).map((r) {
                              final pct = totalScore > 0
                                  ? ((r.riskScore / totalScore) * 100).round()
                                  : 0;
                              return _diagnosisRow(r.diseaseType, pct, r.riskLevel);
                            }),
                          if (_records.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Divider(color: AppColors.divider),
                            const SizedBox(height: 16),
                            _reportSectionLabel('सिफारिश'),
                            const SizedBox(height: 10),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(10)),
                              child: Text(
                                _records.first.recommendation.isNotEmpty
                                    ? _records.first.recommendation
                                    : 'कोई सिफारिश उपलब्ध नहीं।',
                                style: const TextStyle(fontSize: 13,
                                    color: AppColors.textMid, height: 1.5),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          const Divider(color: AppColors.divider),
                          const SizedBox(height: 12),
                          Center(
                            child: Text(
                              'रिपोर्ट ID: ${p.id.substring(0, 8).toUpperCase()}-${DateTime.now().year}',
                              style: const TextStyle(fontSize: 10,
                                  color: AppColors.textHint, letterSpacing: 1),
                            ),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity, height: 56,
                    child: ElevatedButton.icon(
                      onPressed: (_exporting || _records.isEmpty) ? null : _exportPdf,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      icon: _exporting
                          ? const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.download_outlined, color: Colors.white),
                      label: Text(
                        _exporting ? 'PDF बना रहे हैं...' : 'PDF के रूप में निर्यात करें',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportSectionLabel(String text) {
    return Row(children: [
      const Icon(Icons.show_chart, color: AppColors.textLight, size: 14),
      const SizedBox(width: 6),
      Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
          color: AppColors.textLight, letterSpacing: 1.2)),
    ]);
  }

  Widget _infoCol(String label, String value) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textHint, letterSpacing: 0.8)),
      const SizedBox(height: 3),
      Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textDark)),
    ]);
  }

  Widget _diagnosisRow(String name, int pct, String level) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        Expanded(child: Text(name, style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w600, color: AppColors.textDark))),
        Text('$pct%', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: _riskColor(level))),
      ]),
    );
  }
}