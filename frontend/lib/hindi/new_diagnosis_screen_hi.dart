import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import '../../models/patient.dart';
import '../../models/diagnosis_record.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../services/connectivity_service.dart';
import '../../widgets/top_bar.dart';
import '../../widgets/bottom_nav.dart';
import '../../widgets/risk_badge.dart';
import '../../theme.dart';

// ─── Disease types ───────────────────────────────────────────────────────────
enum DiseaseType { maternal, tb, pesticide, dfu }

extension DiseaseTypeExtHi on DiseaseType {
  String get label {
    switch (this) {
      case DiseaseType.maternal:  return 'Maternal Hemorrhage';
      case DiseaseType.tb:        return 'TB Adherence';
      case DiseaseType.pesticide: return 'Pesticide Exposure';
      case DiseaseType.dfu:       return 'Diabetic Foot Ulcer';
    }
  }

  String get labelHi {
    switch (this) {
      case DiseaseType.maternal:  return 'प्रसव रक्तस्राव';
      case DiseaseType.tb:        return 'टीबी अनुपालन';
      case DiseaseType.pesticide: return 'कीटनाशक संपर्क';
      case DiseaseType.dfu:       return 'मधुमेह पैर का घाव';
    }
  }

  IconData get icon {
    switch (this) {
      case DiseaseType.maternal:  return Icons.favorite_border;
      case DiseaseType.tb:        return Icons.medication_outlined;
      case DiseaseType.pesticide: return Icons.eco_outlined;
      case DiseaseType.dfu:       return Icons.accessibility_new;
    }
  }

  Color get color {
    switch (this) {
      case DiseaseType.maternal:  return const Color(0xFFC0392B);
      case DiseaseType.tb:        return AppColors.midGreen;
      case DiseaseType.pesticide: return const Color(0xFF6B8E23);
      case DiseaseType.dfu:       return AppColors.amber;
    }
  }
}

// ─── Screen ──────────────────────────────────────────────────────────────────
class NewDiagnosisScreenHi extends StatefulWidget {
  const NewDiagnosisScreenHi({super.key});

  @override
  State<NewDiagnosisScreenHi> createState() => _NewDiagnosisScreenHiState();
}

class _NewDiagnosisScreenHiState extends State<NewDiagnosisScreenHi>
    with SingleTickerProviderStateMixin {
  int _step = 0;

  List<Patient> _patients = [];
  Patient? _selectedPatient;
  DiseaseType? _selectedDisease;

  bool _isLoading = false;
  DiagnosisRecord? _result;

  List<bool> _actionChecked = [];
  bool _actionsSaved = false;

  // ── Voice input ───────────────────────────────────────────────────────────
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceTranscript = '';
  late AnimationController _micPulseController;
  late Animation<double> _micPulseAnim;

  // ── Reminder ──────────────────────────────────────────────────────────────
  bool _reminderEnabled = false;
  final _reminderMedCtrl  = TextEditingController();
  final _reminderTimeCtrl = TextEditingController();
  String _reminderInterval = '8';

  // ── Maternal ──────────────────────────────────────────────────────────────
  String _mBleedingLevel = 'heavy';
  final _mPulseCtrl = TextEditingController();
  final _mBpCtrl    = TextEditingController();
  String _mWeakness = 'yes';
  final _mDescCtrl  = TextEditingController();

  // ── TB ────────────────────────────────────────────────────────────────────
  final _tbMissedCtrl   = TextEditingController();
  final _tbDaysCtrl     = TextEditingController();
  final _tbDurationCtrl = TextEditingController();
  final _tbSummaryCtrl  = TextEditingController();
  final List<String> _tbAllSymptoms = ['cough', 'fever', 'night_sweats', 'fatigue'];
  List<String> _tbSelectedSymptoms = [];
  String _tbWeightLoss   = 'no';
  String _tbAppetiteLoss = 'no';

  // ── Pesticide ─────────────────────────────────────────────────────────────
  final List<String> _pestAllSymptoms = ['vomiting', 'dizziness', 'headache', 'blurred_vision'];
  List<String> _pestSelectedSymptoms = [];
  final _pestCropCtrl     = TextEditingController();
  String _pestExposure    = 'yes';
  final _pestDurationCtrl = TextEditingController();
  String _pestGear        = 'no';
  final _pestTextCtrl     = TextEditingController();

  // ── DFU ───────────────────────────────────────────────────────────────────
  XFile?     _dfuImageFile;
  Uint8List? _dfuImageBytes;
  String _dfuPain     = 'moderate';
  String _dfuSwelling = 'yes';
  final _dfuDurationCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _speech = stt.SpeechToText();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _micPulseAnim = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _micPulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _mPulseCtrl.dispose();
    _mBpCtrl.dispose();
    _mDescCtrl.dispose();
    _tbMissedCtrl.dispose();
    _tbDaysCtrl.dispose();
    _tbDurationCtrl.dispose();
    _tbSummaryCtrl.dispose();
    _pestCropCtrl.dispose();
    _pestDurationCtrl.dispose();
    _pestTextCtrl.dispose();
    _dfuDurationCtrl.dispose();
    _reminderMedCtrl.dispose();
    _reminderTimeCtrl.dispose();
    _micPulseController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    final patients = await StorageService.getPatients();
    if (mounted) setState(() => _patients = patients);
  }

  // ─── Voice Input ─────────────────────────────────────────────────────────
  Future<void> _startVoiceInput() async {
    if (_selectedDisease == null && _step == 1) {
      _snack('कृपया पहले रोग प्रकार चुनें', isError: true);
      return;
    }

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
            _micPulseController.stop();
            _micPulseController.reset();
          }
          if (_voiceTranscript.isNotEmpty) {
            _parseVoiceInput(_voiceTranscript);
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          _micPulseController.stop();
          _micPulseController.reset();
          _snack('वॉइस त्रुटि: ${error.errorMsg}', isError: true);
        }
      },
    );

    if (available) {
      setState(() {
        _isListening = true;
        _voiceTranscript = '';
      });
      _micPulseController.repeat(reverse: true);
      _showVoiceDialog();

      await _speech.listen(
        onResult: (result) {
          setState(() => _voiceTranscript = result.recognizedWords);
        },
        localeId: 'hi_IN',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
      );
    } else {
      _snack('वॉइस इनपुट उपलब्ध नहीं है', isError: true);
    }
  }

  void _stopVoiceInput() {
    _speech.stop();
    setState(() => _isListening = false);
    _micPulseController.stop();
    _micPulseController.reset();
  }

  void _showVoiceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: false,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 24),

                // Pulsing mic icon
                ScaleTransition(
                  scale: _micPulseAnim,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                        color: AppColors.darkGreen, shape: BoxShape.circle,
                        boxShadow: [BoxShadow(
                            color: AppColors.darkGreen.withOpacity(0.4),
                            blurRadius: 20, spreadRadius: 4)]),
                    child: const Icon(Icons.mic, color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('सुन रहे हैं...',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                        color: AppColors.textDark)),
                const SizedBox(height: 8),

                // Instruction based on disease
                Text(
                  _getVoiceInstruction(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.5),
                ),
                const SizedBox(height: 16),

                // Live transcript
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: ValueNotifier(TextEditingValue(text: _voiceTranscript)),
                  builder: (_, __, ___) => Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      _voiceTranscript.isEmpty ? 'आपकी आवाज़ यहाँ दिखेगी...' : _voiceTranscript,
                      style: TextStyle(
                          fontSize: 14, height: 1.5,
                          color: _voiceTranscript.isEmpty ? AppColors.textHint : AppColors.textDark),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _stopVoiceInput();
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('रद्द करें',
                          style: TextStyle(color: AppColors.textMid)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _stopVoiceInput();
                        Navigator.pop(ctx);
                        if (_voiceTranscript.isNotEmpty) {
                          _parseVoiceInput(_voiceTranscript);
                        }
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('पूर्ण करें'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.darkGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
              ],
            ),
          );
        },
      ),
    ).whenComplete(() {
      if (_isListening) _stopVoiceInput();
    });
  }

  String _getVoiceInstruction() {
    if (_selectedDisease == null) {
      return 'मरीज़ और रोग की जानकारी बोलें';
    }
    switch (_selectedDisease!) {
      case DiseaseType.maternal:
        return 'उदाहरण: "रक्तस्राव भारी है, नाड़ी 110, रक्तचाप 90 बटा 60, कमज़ोरी है"';
      case DiseaseType.tb:
        return 'उदाहरण: "4 खुराक छूटी, 3 दिन से नहीं ली, खांसी और बुखार है, वज़न कम हुआ"';
      case DiseaseType.pesticide:
        return 'उदाहरण: "उल्टी और चक्कर आ रहे हैं, कपास के खेत में 1 घंटे काम किया, दस्ताने नहीं पहने"';
      case DiseaseType.dfu:
        return 'उदाहरण: "दर्द मध्यम है, सूजन है, 5 दिन से घाव है"';
    }
  }

  /// Parse voice transcript and fill form fields intelligently
  void _parseVoiceInput(String text) {
    final lower = text.toLowerCase();
    if (_selectedDisease == null) return;

    setState(() {
      switch (_selectedDisease!) {
        case DiseaseType.maternal:
          _parseMaternalVoice(lower, text);
          break;
        case DiseaseType.tb:
          _parseTbVoice(lower, text);
          break;
        case DiseaseType.pesticide:
          _parsePesticideVoice(lower, text);
          break;
        case DiseaseType.dfu:
          _parseDfuVoice(lower, text);
          break;
      }
    });

    _snack('फ़ॉर्म वॉइस से भरा गया! कृपया जाँचें।');
  }

  void _parseMaternalVoice(String lower, String original) {
    // Bleeding level
    if (lower.contains('भारी') || lower.contains('अधिक') || lower.contains('heavy')) {
      _mBleedingLevel = 'heavy';
    } else if (lower.contains('मध्यम') || lower.contains('moderate')) {
      _mBleedingLevel = 'moderate';
    } else if (lower.contains('हल्का') || lower.contains('कम') || lower.contains('light')) {
      _mBleedingLevel = 'light';
    }

    // Pulse - look for number near 'नाड़ी' or 'pulse' or 'बीपीएम'
    final pulseMatch = RegExp(r'(?:नाड़ी|pulse|पल्स|बीपीएम)[^\d]*(\d+)').firstMatch(lower) ??
        RegExp(r'(\d{2,3})\s*(?:bpm|बीपीएम)').firstMatch(lower);
    if (pulseMatch != null) _mPulseCtrl.text = pulseMatch.group(1)!;

    // BP - look for X/Y or X बटा Y
    final bpMatch = RegExp(r'(\d{2,3})[/\s]*(?:बटा|by|\/)\s*(\d{2,3})').firstMatch(lower);
    if (bpMatch != null) _mBpCtrl.text = '${bpMatch.group(1)}/${bpMatch.group(2)}';

    // Weakness
    if (lower.contains('कमज़ोरी') || lower.contains('कमजोरी') || lower.contains('weakness') || lower.contains('कमज')) {
      _mWeakness = 'yes';
    } else if (lower.contains('कमज़ोरी नहीं') || lower.contains('no weakness')) {
      _mWeakness = 'no';
    }

    // Fill description with full transcript
    _mDescCtrl.text = original;
  }

  void _parseTbVoice(String lower, String original) {
    // Missed doses
    final missedMatch = RegExp(r'(\d+)\s*(?:खुराक|dose|दिन)\s*(?:छूट|miss|नहीं)').firstMatch(lower);
    if (missedMatch != null) _tbMissedCtrl.text = missedMatch.group(1)!;

    // Days since last dose
    final daysMatch = RegExp(r'(\d+)\s*दिन\s*(?:से|पहले|पहले से)').firstMatch(lower);
    if (daysMatch != null) _tbDaysCtrl.text = daysMatch.group(1)!;

    // Symptoms
    if (lower.contains('खांसी') || lower.contains('cough')) _tbSelectedSymptoms.add('cough');
    if (lower.contains('बुखार') || lower.contains('fever')) _tbSelectedSymptoms.add('fever');
    if (lower.contains('रात') && lower.contains('पसीना') || lower.contains('night sweat')) {
      _tbSelectedSymptoms.add('night_sweats');
    }
    if (lower.contains('थकान') || lower.contains('कमज़ोरी') || lower.contains('fatigue')) {
      _tbSelectedSymptoms.add('fatigue');
    }
    _tbSelectedSymptoms = _tbSelectedSymptoms.toSet().toList();

    // Weight loss
    if (lower.contains('वज़न कम') || lower.contains('weight loss')) _tbWeightLoss = 'yes';
    // Appetite loss
    if (lower.contains('भूख नहीं') || lower.contains('appetite')) _tbAppetiteLoss = 'yes';

    _tbSummaryCtrl.text = original;
  }

  void _parsePesticideVoice(String lower, String original) {
    if (lower.contains('उल्टी') || lower.contains('vomit')) _pestSelectedSymptoms.add('vomiting');
    if (lower.contains('चक्कर') || lower.contains('dizzi')) _pestSelectedSymptoms.add('dizziness');
    if (lower.contains('सिरदर्द') || lower.contains('headache')) _pestSelectedSymptoms.add('headache');
    if (lower.contains('धुंधला') || lower.contains('blurred')) _pestSelectedSymptoms.add('blurred_vision');
    _pestSelectedSymptoms = _pestSelectedSymptoms.toSet().toList();

    // Duration
    final durMatch = RegExp(r'(\d+)\s*(?:घंटे|मिनट|hour|minute)').firstMatch(lower);
    if (durMatch != null) _pestDurationCtrl.text = durMatch.group(0)!;

    // Gear
    if (lower.contains('दस्ताने नहीं') || lower.contains('no gear') || lower.contains('gear नहीं')) {
      _pestGear = 'no';
    } else if (lower.contains('दस्ताने') || lower.contains('gear')) {
      _pestGear = 'yes';
    }

    // Crop
    final cropKeywords = ['कपास', 'cotton', 'गेहूं', 'wheat', 'चावल', 'rice', 'मक्का', 'corn'];
    for (final crop in cropKeywords) {
      if (lower.contains(crop)) { _pestCropCtrl.text = crop; break; }
    }

    _pestTextCtrl.text = original;
  }

  void _parseDfuVoice(String lower, String original) {
    if (lower.contains('उच्च') || lower.contains('तेज़') || lower.contains('high')) {
      _dfuPain = 'high';
    } else if (lower.contains('मध्यम') || lower.contains('moderate')) {
      _dfuPain = 'moderate';
    } else if (lower.contains('कम') || lower.contains('हल्का') || lower.contains('low')) {
      _dfuPain = 'low';
    }

    if (lower.contains('सूजन है') || lower.contains('swelling')) _dfuSwelling = 'yes';
    if (lower.contains('सूजन नहीं') || lower.contains('no swelling')) _dfuSwelling = 'no';

    final durMatch = RegExp(r'(\d+)\s*(?:दिन|day|week|हफ्त)').firstMatch(lower);
    if (durMatch != null) _dfuDurationCtrl.text = durMatch.group(0)!;
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _goToForm() {
    if (_selectedPatient == null) { _snack('कृपया मरीज़ चुनें', isError: true); return; }
    if (_selectedDisease == null) { _snack('कृपया जांच प्रकार चुनें', isError: true); return; }
    setState(() => _step = 1);
  }

  void _finishAndGoHome() {
    _sendSmsReminder();
    Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _sendSmsReminder() async {
    if (!_reminderEnabled || _result == null) return;
    final phone   = _selectedPatient?.phone ?? '';
    final medName = _reminderMedCtrl.text.trim();
    final time    = _reminderTimeCtrl.text.trim();
    if (phone.isEmpty || phone.length < 10 || medName.isEmpty || time.isEmpty) return;

    final message =
        'SenseAI अनुस्मारक: ${_result!.patientName} को दवा "$medName" '
        '$time बजे से हर $_reminderInterval घंटे में दें। - स्वास्थ्य कार्यकर्ता';
    final Uri smsUri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
    try {
      if (await canLaunchUrl(smsUri)) await launchUrl(smsUri);
    } catch (_) {}
  }

  Future<void> _saveCheckedActions() async {
    if (_result == null) return;
    final indices = <int>[];
    for (int i = 0; i < _actionChecked.length; i++) {
      if (_actionChecked[i]) indices.add(i);
    }
    final updated = DiagnosisRecord(
      id: _result!.id, patientId: _result!.patientId,
      patientName: _result!.patientName, diseaseType: _result!.diseaseType,
      inputs: _result!.inputs, apiResponse: _result!.apiResponse,
      timestamp: _result!.timestamp, checkedActions: indices,
    );
    await StorageService.saveDiagnosis(updated);
    if (mounted) setState(() { _result = updated; _actionsSaved = true; });
    _snack('चेकलिस्ट सहेजी गई!');
  }

  Future<void> _submitDiagnosis() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> inputs = {};
      Map<String, dynamic> apiResponse = {};
      final online = ConnectivityService().isOnline;

      if (online) {
        switch (_selectedDisease!) {
          case DiseaseType.maternal:
            inputs = {
              'bleeding_level': _mBleedingLevel,
              'pulse':          int.tryParse(_mPulseCtrl.text) ?? 0,
              'bp':             _mBpCtrl.text.trim(),
              'weakness':       _mWeakness,
              'description':    _mDescCtrl.text.trim(),
            };
            apiResponse = await ApiService.diagnoseMaternel(inputs);
            break;
          case DiseaseType.tb:
            inputs = {
              'missed_doses':         int.tryParse(_tbMissedCtrl.text) ?? 0,
              'days_since_last_dose': int.tryParse(_tbDaysCtrl.text) ?? 0,
              'symptoms':             _tbSelectedSymptoms,
              'weight_loss':          _tbWeightLoss,
              'appetite_loss':        _tbAppetiteLoss,
              'duration_of_symptoms': _tbDurationCtrl.text.trim(),
              'past_summary':         _tbSummaryCtrl.text.trim(),
              'age':                  _selectedPatient!.age,
            };
            apiResponse = await ApiService.diagnoseTb(inputs);
            break;
          case DiseaseType.pesticide:
            inputs = {
              'symptoms':        _pestSelectedSymptoms,
              'crop_type':       _pestCropCtrl.text.trim(),
              'recent_exposure': _pestExposure,
              'duration':        _pestDurationCtrl.text.trim(),
              'protective_gear': _pestGear,
              'text_input':      _pestTextCtrl.text.trim(),
            };
            apiResponse = await ApiService.diagnosePesticide(inputs);
            break;
          case DiseaseType.dfu:
            if (_dfuImageFile == null) {
              _snack('कृपया पहले पैर की फोटो लें', isError: true);
              setState(() => _isLoading = false);
              return;
            }
            inputs = { 'pain': _dfuPain, 'swelling': _dfuSwelling, 'duration': _dfuDurationCtrl.text.trim() };
            apiResponse = await ApiService.diagnoseDfu(
              image: File(_dfuImageFile!.path),
              pain: _dfuPain, swelling: _dfuSwelling, duration: _dfuDurationCtrl.text.trim(), language: '',
            );
            break;
        }
      } else {
        inputs = {'offline': true};
        apiResponse = {
          'risk_level': 'UNKNOWN', 'risk_score': 0,
          'recommendation': 'ऑफ़लाइन — डेटा कतार में है। कनेक्ट होने पर सिंक होगा।',
          'checklist': ['सिंक लंबित — पूर्ण मूल्यांकन के लिए फिर से कनेक्ट करें।'],
          'explanation': 'कोई नेटवर्क कनेक्शन नहीं। डेटा सिंक के लिए सहेजा गया।',
          'missing_data': [],
        };
        await StorageService.addToSyncQueue(_selectedDisease!.label, inputs);
      }

      final record = DiagnosisRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        diseaseType: _selectedDisease!.label,
        inputs: inputs, apiResponse: apiResponse,
        timestamp: DateTime.now().toIso8601String(),
        checkedActions: const [],
      );
      await StorageService.saveDiagnosis(record);

      if (mounted) {
        final checklist = record.checklist;
        setState(() {
          _result = record;
          _actionChecked = List.filled(checklist.length, false);
          _actionsSaved = false;
          _step = 2;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('त्रुटि: $e', isError: true);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.redAccent : AppColors.darkGreen,
      duration: const Duration(seconds: 2),
    ));
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with mic button
            _buildTopBarWithMic(),
            Expanded(
              child: _step == 0
                  ? _buildStep0()
                  : _step == 1
                  ? _buildStep1()
                  : _buildStep2(),
            ),
          ],
        ),
      ),
      bottomNavigationBar: RuraxBottomNav(
        selectedIndex: 1,
        onTap: (i) { if (i == 0) Navigator.popUntil(context, (r) => r.isFirst); },
      ),
    );
  }

  Widget _buildTopBarWithMic() {
    return Container(
      color: AppColors.darkGreen,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.only(
              left: 16, right: 16,
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 10,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_step > 0) {
                      setState(() { _step -= 1; _result = null; });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                const Text('नई जांच',
                    style: TextStyle(color: Colors.white, fontSize: 18,
                        fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const Spacer(),
                // Mic button — only on step 1 (form)
                if (_step == 1)
                  GestureDetector(
                    onTap: _isListening ? _stopVoiceInput : _startVoiceInput,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: _isListening
                            ? Colors.white
                            : Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _isListening ? Colors.white : Colors.white38,
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: _isListening ? AppColors.darkGreen : Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isListening ? 'रोकें' : 'बोलें',
                            style: TextStyle(
                              color: _isListening ? AppColors.darkGreen : Colors.white,
                              fontSize: 12, fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Status bar
          Container(
            color: AppColors.statusGreen,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            child: Row(
              children: [
                const Icon(Icons.person_outline, color: Colors.white70, size: 14),
                const SizedBox(width: 4),
                const Text('स्वास्थ्य कार्यकर्ता',
                    style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 1)),
                const Spacer(),
                StreamBuilder<SyncStatus>(
                  stream: ConnectivityService().statusStream,
                  initialData: ConnectivityService().status,
                  builder: (_, snap) {
                    final online = ConnectivityService().isOnline;
                    return Row(children: [
                      Icon(online ? Icons.wifi : Icons.wifi_off,
                          color: online ? Colors.lightGreenAccent : Colors.orangeAccent, size: 12),
                      const SizedBox(width: 4),
                      Text(online ? 'ऑनलाइन' : 'ऑफ़लाइन',
                          style: TextStyle(
                              color: online ? Colors.lightGreenAccent : Colors.orangeAccent,
                              fontSize: 11)),
                    ]);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── STEP 0 ───────────────────────────────────────────────────────────────

  Widget _buildStep0() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('नई जांच',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                  color: AppColors.textDark, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          const Text('मरीज़ और रोग चुनें',
              style: TextStyle(fontSize: 11, color: AppColors.textLight, letterSpacing: 1.2)),
          const SizedBox(height: 24),

          _sectionLabel('मरीज़'),
          const SizedBox(height: 8),
          if (_patients.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.textHint),
                SizedBox(width: 8),
                Text('अभी तक कोई मरीज़ पंजीकृत नहीं।',
                    style: TextStyle(color: AppColors.textMid)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Patient>(
                  isExpanded: true,
                  hint: const Text('मरीज़ चुनें', style: TextStyle(color: AppColors.textHint)),
                  value: _selectedPatient,
                  items: _patients.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  onChanged: (p) {
                    setState(() {
                      _selectedPatient = p;
                      if (p != null && p.gender.toLowerCase() == 'male' &&
                          _selectedDisease == DiseaseType.maternal) {
                        _selectedDisease = null;
                      }
                    });
                  },
                ),
              ),
            ),

          if (_selectedPatient != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: AppColors.darkGreen.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.darkGreen.withOpacity(0.2))),
              child: Row(children: [
                const Icon(Icons.person, color: AppColors.darkGreen, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${_selectedPatient!.name}  •  आयु ${_selectedPatient!.age}  •  ${_selectedPatient!.gender}',
                    style: const TextStyle(fontSize: 13, color: AppColors.darkGreen,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 24),
          _sectionLabel('जांच प्रकार'),
          const SizedBox(height: 12),
          ...DiseaseType.values.where((d) {
            if (d == DiseaseType.maternal && _selectedPatient != null &&
                _selectedPatient!.gender.toLowerCase() == 'male') return false;
            return true;
          }).map((d) => _buildDiseaseCard(d)),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _goToForm,
              child: const Text('आगे बढ़ें',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDiseaseCard(DiseaseType d) {
    final selected = _selectedDisease == d;
    return GestureDetector(
      onTap: () => setState(() => _selectedDisease = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? d.color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? d.color : AppColors.divider, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: d.color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Icon(d.icon, color: d.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.labelHi, style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600,
                  color: selected ? d.color : AppColors.textDark)),
              Text(d.label, style: TextStyle(
                  fontSize: 11, color: selected ? d.color.withOpacity(0.7) : AppColors.textLight)),
            ]),
          ),
          if (selected) Icon(Icons.check_circle, color: d.color, size: 22),
        ]),
      ),
    );
  }

  // ─── STEP 1 ───────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Voice hint banner
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.darkGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkGreen.withOpacity(0.2)),
            ),
            child: Row(children: [
              const Icon(Icons.mic_none, color: AppColors.darkGreen, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ऊपर "बोलें" बटन दबाएं और फ़ॉर्म स्वचालित रूप से भरें',
                  style: TextStyle(fontSize: 12, color: AppColors.darkGreen, height: 1.4),
                ),
              ),
            ]),
          ),

          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                  color: _selectedDisease!.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(_selectedDisease!.labelHi,
                  style: TextStyle(color: _selectedDisease!.color,
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 6),
          Text(_selectedPatient!.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text('आयु ${_selectedPatient!.age}  •  ${_selectedPatient!.gender}',
              style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 24),
          const Text('मरीज़ की जानकारी',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                  color: AppColors.textLight, letterSpacing: 1.2)),
          const SizedBox(height: 14),
          _buildDiseaseForm(),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitDiagnosis,
              style: ElevatedButton.styleFrom(backgroundColor: _selectedDisease!.color),
              child: _isLoading
                  ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('जांच करें',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDiseaseForm() {
    switch (_selectedDisease!) {
      case DiseaseType.maternal:  return _maternalForm();
      case DiseaseType.tb:        return _tbForm();
      case DiseaseType.pesticide: return _pesticideForm();
      case DiseaseType.dfu:       return _dfuForm();
    }
  }

  Widget _maternalForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _formLabel('रक्तस्राव का स्तर'), const SizedBox(height: 6),
      _chipSelector(options: ['light', 'moderate', 'heavy'],
          labels: ['हल्का', 'मध्यम', 'भारी'],
          selected: _mBleedingLevel,
          onSelect: (v) => setState(() => _mBleedingLevel = v)),
      const SizedBox(height: 14),
      _formLabel('नाड़ी (bpm)'), const SizedBox(height: 6),
      _inputField(_mPulseCtrl, 'जैसे: 110', TextInputType.number),
      const SizedBox(height: 14),
      _formLabel('रक्तचाप'), const SizedBox(height: 6),
      _inputField(_mBpCtrl, 'जैसे: 90/60', TextInputType.text),
      const SizedBox(height: 14),
      _formLabel('कमज़ोरी'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'], labels: ['हाँ', 'नहीं'],
          selected: _mWeakness, onSelect: (v) => setState(() => _mWeakness = v)),
      const SizedBox(height: 14),
      _formLabel('विवरण'), const SizedBox(height: 6),
      _inputField(_mDescCtrl, 'लक्षणों का विस्तार से वर्णन करें...', TextInputType.multiline, maxLines: 3),
    ],
  );

  Widget _tbForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _formLabel('छूटी हुई खुराक'), const SizedBox(height: 6),
      _inputField(_tbMissedCtrl, 'जैसे: 4', TextInputType.number),
      const SizedBox(height: 14),
      _formLabel('आखिरी खुराक के बाद दिन'), const SizedBox(height: 6),
      _inputField(_tbDaysCtrl, 'जैसे: 3', TextInputType.number),
      const SizedBox(height: 14),
      _formLabel('लक्षण'), const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8,
          children: [
            _symptomChipHi('cough', 'खांसी'),
            _symptomChipHi('fever', 'बुखार'),
            _symptomChipHi('night_sweats', 'रात में पसीना'),
            _symptomChipHi('fatigue', 'थकान'),
          ]),
      const SizedBox(height: 14),
      _formLabel('वज़न कम'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'], labels: ['हाँ', 'नहीं'],
          selected: _tbWeightLoss, onSelect: (v) => setState(() => _tbWeightLoss = v)),
      const SizedBox(height: 14),
      _formLabel('भूख न लगना'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'], labels: ['हाँ', 'नहीं'],
          selected: _tbAppetiteLoss, onSelect: (v) => setState(() => _tbAppetiteLoss = v)),
      const SizedBox(height: 14),
      _formLabel('लक्षणों की अवधि'), const SizedBox(height: 6),
      _inputField(_tbDurationCtrl, 'जैसे: 3 हफ्ते', TextInputType.text),
      const SizedBox(height: 14),
      _formLabel('पुराना विवरण'), const SizedBox(height: 6),
      _inputField(_tbSummaryCtrl, 'मरीज़ का इतिहास...', TextInputType.multiline, maxLines: 3),
    ],
  );

  Widget _pestSymptomChipHi(String value, String label) {
    final sel = _pestSelectedSymptoms.contains(value);
    return GestureDetector(
      onTap: () => setState(() {
        sel ? _pestSelectedSymptoms.remove(value) : _pestSelectedSymptoms.add(value);
      }),
      child: _chipWidget(label, sel),
    );
  }

  Widget _symptomChipHi(String value, String label) {
    final sel = _tbSelectedSymptoms.contains(value);
    return GestureDetector(
      onTap: () => setState(() {
        sel ? _tbSelectedSymptoms.remove(value) : _tbSelectedSymptoms.add(value);
      }),
      child: _chipWidget(label, sel),
    );
  }

  Widget _pesticideForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _formLabel('लक्षण'), const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _pestSymptomChipHi('vomiting', 'उल्टी'),
        _pestSymptomChipHi('dizziness', 'चक्कर'),
        _pestSymptomChipHi('headache', 'सिरदर्द'),
        _pestSymptomChipHi('blurred_vision', 'धुंधला दिखना'),
      ]),
      const SizedBox(height: 14),
      _formLabel('फसल का प्रकार'), const SizedBox(height: 6),
      _inputField(_pestCropCtrl, 'जैसे: कपास', TextInputType.text),
      const SizedBox(height: 14),
      _formLabel('हाल में संपर्क'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'], labels: ['हाँ', 'नहीं'],
          selected: _pestExposure, onSelect: (v) => setState(() => _pestExposure = v)),
      const SizedBox(height: 14),
      _formLabel('संपर्क की अवधि'), const SizedBox(height: 6),
      _inputField(_pestDurationCtrl, 'जैसे: 1 घंटा', TextInputType.text),
      const SizedBox(height: 14),
      _formLabel('सुरक्षात्मक उपकरण'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'], labels: ['हाँ', 'नहीं'],
          selected: _pestGear, onSelect: (v) => setState(() => _pestGear = v)),
      const SizedBox(height: 14),
      _formLabel('विवरण'), const SizedBox(height: 6),
      _inputField(_pestTextCtrl, 'क्या हुआ इसका वर्णन करें...', TextInputType.multiline, maxLines: 3),
    ],
  );

  Widget _dfuForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _formLabel('पैर की फोटो'), const SizedBox(height: 8),
      GestureDetector(
        onTap: _pickImage,
        child: Container(
          width: double.infinity, height: 180,
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider)),
          child: _dfuImageFile == null
              ? const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.camera_alt_outlined, color: AppColors.textHint, size: 40),
            SizedBox(height: 8),
            Text('पैर की फोटो लेने के लिए टैप करें',
                style: TextStyle(color: AppColors.textHint, fontSize: 13)),
          ])
              : ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: kIsWeb
                  ? Image.memory(_dfuImageBytes!, fit: BoxFit.cover)
                  : Image.file(File(_dfuImageFile!.path), fit: BoxFit.cover)),
        ),
      ),
      const SizedBox(height: 14),
      _formLabel('दर्द का स्तर'), const SizedBox(height: 6),
      _chipSelector(options: ['low', 'moderate', 'high'],
          labels: ['कम', 'मध्यम', 'अधिक'],
          selected: _dfuPain, onSelect: (v) => setState(() => _dfuPain = v)),
      const SizedBox(height: 14),
      _formLabel('सूजन'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'], labels: ['हाँ', 'नहीं'],
          selected: _dfuSwelling, onSelect: (v) => setState(() => _dfuSwelling = v)),
      const SizedBox(height: 14),
      _formLabel('अवधि'), const SizedBox(height: 6),
      _inputField(_dfuDurationCtrl, 'जैसे: 5 दिन', TextInputType.text),
    ],
  );

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 80);
    if (picked != null && mounted) {
      if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        setState(() { _dfuImageFile = picked; _dfuImageBytes = bytes; });
      } else {
        setState(() => _dfuImageFile = picked);
      }
    }
  }

  // ─── STEP 2 ───────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    final r = _result!;
    final checklist = r.checklist;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('जांच परिणाम',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                  color: AppColors.textDark, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(r.patientName, style: const TextStyle(fontSize: 14, color: AppColors.textLight)),
          const SizedBox(height: 16),

          RiskBadge(level: r.riskLevel, score: r.riskScore),
          const SizedBox(height: 16),

          _resultSection('विवरण', (r.apiResponse['explanation'] ?? '').toString()),
          _resultSection('सिफारिश', r.recommendation),

          if (checklist.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(
                child: Text('कार्य सूची',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.textLight, letterSpacing: 1.2)),
              ),
              if (_actionsSaved)
                const Row(children: [
                  Icon(Icons.check_circle, color: AppColors.darkGreen, size: 15),
                  SizedBox(width: 4),
                  Text('सहेजा गया', style: TextStyle(fontSize: 12,
                      color: AppColors.darkGreen, fontWeight: FontWeight.w600)),
                ]),
            ]),
            const SizedBox(height: 4),
            const Text('पूर्ण किए गए कार्य टिक करें — मरीज़ के इतिहास में सहेजे जाएंगे।',
                style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 10),

            ...List.generate(checklist.length, (i) {
              final checked = _actionChecked.length > i && _actionChecked[i];
              return GestureDetector(
                onTap: () => setState(() {
                  _actionChecked[i] = !_actionChecked[i];
                  _actionsSaved = false;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: checked ? AppColors.darkGreen.withOpacity(0.07) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: checked ? AppColors.darkGreen.withOpacity(0.4) : AppColors.divider),
                  ),
                  child: Row(children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: Icon(
                        checked ? Icons.check_circle : Icons.radio_button_unchecked,
                        key: ValueKey(checked),
                        color: checked ? AppColors.darkGreen : AppColors.textHint,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(checklist[i],
                        style: TextStyle(fontSize: 13, height: 1.4,
                            color: checked ? AppColors.darkGreen : AppColors.textMid,
                            fontWeight: checked ? FontWeight.w600 : FontWeight.normal))),
                  ]),
                ),
              );
            }),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity, height: 46,
              child: OutlinedButton.icon(
                onPressed: _actionsSaved ? null : _saveCheckedActions,
                icon: Icon(_actionsSaved ? Icons.check : Icons.save_outlined,
                    size: 18,
                    color: _actionsSaved ? AppColors.textHint : AppColors.darkGreen),
                label: Text(
                  _actionsSaved ? 'चेकलिस्ट सहेजी गई' : 'चेकलिस्ट सहेजें',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: _actionsSaved ? AppColors.textHint : AppColors.darkGreen),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _actionsSaved ? AppColors.divider : AppColors.darkGreen),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],

          if ((r.apiResponse['missing_data'] as List?)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.amber.shade50, borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.amber.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('छूटा हुआ डेटा',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                          color: AppColors.amber, letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  ...(r.apiResponse['missing_data'] as List).map((m) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('• ', style: TextStyle(color: AppColors.amber)),
                      Expanded(child: Text(m.toString(),
                          style: const TextStyle(fontSize: 13, color: AppColors.textMid, height: 1.4))),
                    ]),
                  )),
                ],
              ),
            ),
          ],

          // Reminder section
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('दवा अनुस्मारक सेट करें',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      SizedBox(height: 2),
                      Text('मरीज़ के नंबर पर SMS अनुस्मारक भेजें',
                          style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                    ]),
                  ),
                  Switch(value: _reminderEnabled, activeColor: AppColors.darkGreen,
                      onChanged: (v) => setState(() => _reminderEnabled = v)),
                ]),

                if (_reminderEnabled) ...[
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.divider),
                  const SizedBox(height: 14),

                  if ((_selectedPatient?.phone ?? '').isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                          color: AppColors.darkGreen.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.phone_outlined, color: AppColors.darkGreen, size: 16),
                        const SizedBox(width: 8),
                        Text('SMS यहाँ भेजा जाएगा: ${_selectedPatient!.phone}',
                            style: const TextStyle(fontSize: 12, color: AppColors.darkGreen,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),

                  const Text('दवा का नाम',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMid)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: AppColors.background,
                        borderRadius: BorderRadius.circular(10)),
                    child: TextField(
                      controller: _reminderMedCtrl,
                      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                      decoration: const InputDecoration(
                        hintText: 'जैसे: ऑक्सीटोसिन, रिफाम्पिसिन...',
                        prefixIcon: Icon(Icons.medication_outlined, color: AppColors.textHint, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('शुरू करने का समय',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMid)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: AppColors.background,
                        borderRadius: BorderRadius.circular(10)),
                    child: TextField(
                      controller: _reminderTimeCtrl,
                      readOnly: true,
                      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                      decoration: const InputDecoration(
                        hintText: 'समय चुनने के लिए टैप करें',
                        prefixIcon: Icon(Icons.access_time, color: AppColors.textHint, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                      onTap: () async {
                        final picked = await showTimePicker(
                            context: context, initialTime: TimeOfDay.now());
                        if (picked != null && mounted) {
                          setState(() => _reminderTimeCtrl.text = picked.format(context));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  const Text('हर कितने घंटे में',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMid)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(color: AppColors.background,
                        borderRadius: BorderRadius.circular(10)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _reminderInterval,
                        isExpanded: true,
                        items: ['4', '6', '8', '12', '24'].map((h) => DropdownMenuItem(
                            value: h, child: Text('हर $h घंटे में'))).toList(),
                        onChanged: (v) => setState(() => _reminderInterval = v ?? '8'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _finishAndGoHome,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('समाप्त करें',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  Widget _resultSection(String title, String content) {
    if (content.isEmpty) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title.toUpperCase(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textLight, letterSpacing: 1.1)),
        const SizedBox(height: 8),
        Text(content, style: const TextStyle(fontSize: 14, color: AppColors.textMid, height: 1.5)),
      ]),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textLight, letterSpacing: 1.2));

  Widget _formLabel(String text) => Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMid));

  Widget _inputField(TextEditingController ctrl, String hint, TextInputType type, {int maxLines = 1}) =>
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: TextField(
          controller: ctrl,
          keyboardType: type,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      );

  Widget _chipSelector({
    required List<String> options,
    required List<String> labels,
    required String selected,
    required ValueChanged<String> onSelect,
  }) =>
      Wrap(
        spacing: 8,
        children: List.generate(options.length, (i) => GestureDetector(
            onTap: () => onSelect(options[i]),
            child: _chipWidget(labels[i], selected == options[i]))),
      );

  Widget _chipWidget(String label, bool selected) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    decoration: BoxDecoration(
      color: selected ? AppColors.darkGreen : Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: selected ? AppColors.darkGreen : AppColors.divider),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textMid)),
  );
}