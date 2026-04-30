import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:url_launcher/url_launcher.dart';
import '../models/patient.dart';
import '../models/diagnosis_record.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../widgets/top_bar.dart';
import '../widgets/bottom_nav.dart';
import '../widgets/risk_badge.dart';
import '../theme.dart';

// ─── Disease types ──────────────────────────────────────────────────────────
enum DiseaseType { maternal, tb, pesticide, dfu }

extension DiseaseTypeExt on DiseaseType {
  String get label {
    switch (this) {
      case DiseaseType.maternal:  return 'Maternal Hemorrhage';
      case DiseaseType.tb:        return 'TB Adherence';
      case DiseaseType.pesticide: return 'Pesticide Exposure';
      case DiseaseType.dfu:       return 'Diabetic Foot Ulcer';
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

// ─── Screen ─────────────────────────────────────────────────────────────────
class NewDiagnosisScreen extends StatefulWidget {
  const NewDiagnosisScreen({super.key});

  @override
  State<NewDiagnosisScreen> createState() => _NewDiagnosisScreenState();
}

class _NewDiagnosisScreenState extends State<NewDiagnosisScreen>
    with SingleTickerProviderStateMixin {
  // Steps: 0 = select patient+disease, 1 = form, 2 = result
  int _step = 0;

  List<Patient> _patients = [];
  Patient? _selectedPatient;
  DiseaseType? _selectedDisease;

  // ── Language selection ────────────────────────────────────────────────────
  String _selectedLanguage = 'english';

  bool _isLoading = false;
  DiagnosisRecord? _result;

  // Track whether last result was from offline engine
  bool _wasOffline = false;

  // Output checklist (Step 2)
  List<bool> _actionChecked = [];
  bool _actionsSaved = false;

  // ── Voice input ───────────────────────────────────────────────────────────
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _voiceTranscript = '';
  // Which field is currently being recorded (null = top-bar global mode)
  TextEditingController? _activeVoiceController;
  late AnimationController _micPulseController;
  late Animation<double> _micPulseAnim;

  // ── Reminder state ────────────────────────────────────────────────────────
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
  final _pestCropCtrl      = TextEditingController();
  String _pestExposure     = 'yes';
  final _pestDurationCtrl  = TextEditingController();
  String _pestGear         = 'no';
  final _pestTextCtrl      = TextEditingController();

  // ── DFU ───────────────────────────────────────────────────────────────────
  XFile?    _dfuImageFile;
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

  // ─── Per-field Voice Input ────────────────────────────────────────────────
  Future<bool> _requestMicPermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) {
      _snack('Mic permission permanently denied. Enable it in Settings.', isError: true);
      openAppSettings();
      return false;
    }
    _snack('Microphone permission is required for voice input', isError: true);
    return false;
  }
  /// Call this when the user taps the mic icon next to a specific text field.
  /// [controller] is the TextEditingController for that field.
  /// [hint] is the example hint shown in the dialog.
  Future<void> _startFieldVoiceInput({
    required TextEditingController controller,
    required String hint,
  }) async {
    // Pick locale based on selected language
    final localeId = _selectedLanguage == 'hindi' ? 'hi_IN' : 'en_IN';

    bool available = await _speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (mounted) {
            setState(() => _isListening = false);
            _micPulseController.stop();
            _micPulseController.reset();
          }
          // Append the transcript to the field
          if (_voiceTranscript.isNotEmpty && _activeVoiceController != null) {
            final existing = _activeVoiceController!.text.trim();
            _activeVoiceController!.text =
            existing.isEmpty ? _voiceTranscript : '$existing $_voiceTranscript';
          }
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          _micPulseController.stop();
          _micPulseController.reset();
          _snack('Voice error: ${error.errorMsg}', isError: true);
        }
      },
    );

    if (!available) {
      _snack('Voice input not available on this device', isError: true);
      return;
    }

    setState(() {
      _isListening = true;
      _voiceTranscript = '';
      _activeVoiceController = controller;
    });
    _micPulseController.repeat(reverse: true);
    _showFieldVoiceDialog(controller: controller, hint: hint);

    await _speech.listen(
      onResult: (result) => setState(() => _voiceTranscript = result.recognizedWords),
      localeId: localeId,
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
    );
  }

  void _stopFieldVoiceInput({bool apply = true}) {
    _speech.stop();
    if (apply && _voiceTranscript.isNotEmpty && _activeVoiceController != null) {
      final existing = _activeVoiceController!.text.trim();
      _activeVoiceController!.text =
      existing.isEmpty ? _voiceTranscript : '$existing $_voiceTranscript';
    }
    setState(() {
      _isListening = false;
      _voiceTranscript = '';
      _activeVoiceController = null;
    });
    _micPulseController.stop();
    _micPulseController.reset();
  }

  void _showFieldVoiceDialog({
    required TextEditingController controller,
    required String hint,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isDismissible: false,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          // Sync modal state with parent state
          _speech.statusListener = (status) {
            if (mounted) setModalState(() {});
          };
          return Padding(
            padding: EdgeInsets.only(
              left: 28, right: 28, top: 28,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 24),

                // Language badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.darkGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.language, color: AppColors.darkGreen, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      _selectedLanguage == 'hindi'
                          ? 'हिन्दी में बोलें'
                          : 'Speak in English',
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Pulsing mic
                ScaleTransition(
                  scale: _micPulseAnim,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                        color: _isListening ? AppColors.darkGreen : AppColors.divider,
                        shape: BoxShape.circle,
                        boxShadow: _isListening
                            ? [BoxShadow(
                            color: AppColors.darkGreen.withOpacity(0.4),
                            blurRadius: 20,
                            spreadRadius: 4)]
                            : []),
                    child: const Icon(Icons.mic, color: Colors.white, size: 38),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  _isListening ? 'Listening...' : 'Processing...',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark),
                ),
                const SizedBox(height: 6),
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textLight, height: 1.5),
                ),
                const SizedBox(height: 16),

                // Live transcript box
                StatefulBuilder(builder: (_, setSt) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    constraints: const BoxConstraints(minHeight: 60, maxHeight: 140),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: _voiceTranscript.isNotEmpty
                                ? AppColors.darkGreen.withOpacity(0.4)
                                : AppColors.divider)),
                    child: SingleChildScrollView(
                      child: Text(
                        _voiceTranscript.isEmpty
                            ? (_selectedLanguage == 'hindi'
                            ? 'आपकी आवाज़ यहाँ दिखेगी...'
                            : 'Your speech will appear here...')
                            : _voiceTranscript,
                        style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: _voiceTranscript.isEmpty
                                ? AppColors.textHint
                                : AppColors.textDark),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 20),

                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _stopFieldVoiceInput(apply: false);
                        Navigator.pop(ctx);
                      },
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.divider),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      child: const Text('Cancel',
                          style: TextStyle(color: AppColors.textMid)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _stopFieldVoiceInput(apply: true);
                        Navigator.pop(ctx);
                        _snack('Text added to field!');
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Use This'),
                      style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          backgroundColor: AppColors.darkGreen,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
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
      if (_isListening) _stopFieldVoiceInput(apply: false);
    });
  }

  // ─── Global Voice Input (top bar) ─────────────────────────────────────────

  Future<void> _startVoiceInput() async {
    if (_selectedDisease == null) {
      _snack('Please select a disease type first', isError: true);
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
          if (_voiceTranscript.isNotEmpty) _parseVoiceInput(_voiceTranscript);
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isListening = false);
          _micPulseController.stop();
          _micPulseController.reset();
          _snack('Voice error: ${error.errorMsg}', isError: true);
        }
      },
    );

    if (available) {
      setState(() { _isListening = true; _voiceTranscript = ''; _activeVoiceController = null; });
      _micPulseController.repeat(reverse: true);
      _showVoiceDialog();

      final localeId = _selectedLanguage == 'hindi' ? 'hi_IN' : 'en_IN';
      await _speech.listen(
        onResult: (result) => setState(() => _voiceTranscript = result.recognizedWords),
        localeId: localeId,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
        partialResults: true,
      );
    } else {
      _snack('Voice input not available', isError: true);
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
        builder: (ctx, setModalState) => Padding(
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
              ScaleTransition(
                scale: _micPulseAnim,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                      color: AppColors.darkGreen, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: AppColors.darkGreen.withOpacity(0.4),
                          blurRadius: 20, spreadRadius: 4)]),
                  child: const Icon(Icons.mic, color: Colors.white, size: 38),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Listening...',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppColors.textDark)),
              const SizedBox(height: 8),
              Text(
                _getVoiceInstruction(),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textLight, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: AppColors.background, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _voiceTranscript.isEmpty ? 'Your speech will appear here...' : _voiceTranscript,
                  style: TextStyle(fontSize: 14, height: 1.5,
                      color: _voiceTranscript.isEmpty ? AppColors.textHint : AppColors.textDark),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () { _stopVoiceInput(); Navigator.pop(ctx); },
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.divider),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: const Text('Cancel', style: TextStyle(color: AppColors.textMid)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _stopVoiceInput();
                      Navigator.pop(ctx);
                      if (_voiceTranscript.isNotEmpty) _parseVoiceInput(_voiceTranscript);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Done'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.darkGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).whenComplete(() { if (_isListening) _stopVoiceInput(); });
  }

  String _getVoiceInstruction() {
    if (_selectedDisease == null) return 'Speak patient and disease information';
    switch (_selectedDisease!) {
      case DiseaseType.maternal:
        return 'e.g. "Heavy bleeding, pulse 110, BP 90 over 60, has weakness"';
      case DiseaseType.tb:
        return 'e.g. "Missed 4 doses, 3 days since last dose, has cough and fever, lost weight"';
      case DiseaseType.pesticide:
        return 'e.g. "Has vomiting and dizziness, worked in cotton field for 1 hour, no gloves"';
      case DiseaseType.dfu:
        return 'e.g. "Moderate pain, has swelling, wound for 5 days"';
    }
  }

  void _parseVoiceInput(String text) {
    final lower = text.toLowerCase();
    if (_selectedDisease == null) return;

    setState(() {
      switch (_selectedDisease!) {
        case DiseaseType.maternal:  _parseMaternalVoice(lower, text); break;
        case DiseaseType.tb:        _parseTbVoice(lower, text); break;
        case DiseaseType.pesticide: _parsePesticideVoice(lower, text); break;
        case DiseaseType.dfu:       _parseDfuVoice(lower, text); break;
      }
    });

    _snack('Form filled from voice! Please review.');
  }

  void _parseMaternalVoice(String lower, String original) {
    if (lower.contains('heavy') || lower.contains('severe')) {
      _mBleedingLevel = 'heavy';
    } else if (lower.contains('moderate')) {
      _mBleedingLevel = 'moderate';
    } else if (lower.contains('light') || lower.contains('mild')) {
      _mBleedingLevel = 'light';
    }
    final pulseMatch = RegExp(r'(?:pulse|heart rate)[^\d]*(\d+)').firstMatch(lower) ??
        RegExp(r'(\d{2,3})\s*bpm').firstMatch(lower);
    if (pulseMatch != null) _mPulseCtrl.text = pulseMatch.group(1)!;
    final bpMatch = RegExp(r'(\d{2,3})\s*(?:over|\/)\s*(\d{2,3})').firstMatch(lower);
    if (bpMatch != null) _mBpCtrl.text = '${bpMatch.group(1)}/${bpMatch.group(2)}';
    if (lower.contains('weakness') || lower.contains('weak')) _mWeakness = 'yes';
    else if (lower.contains('no weakness') || lower.contains('not weak')) _mWeakness = 'no';
    _mDescCtrl.text = original;
  }

  void _parseTbVoice(String lower, String original) {
    final missedMatch = RegExp(r'(?:missed|skipped)\s*(\d+)\s*(?:dose|doses)').firstMatch(lower);
    if (missedMatch != null) _tbMissedCtrl.text = missedMatch.group(1)!;
    final daysMatch = RegExp(r'(\d+)\s*days?\s*(?:since|ago)').firstMatch(lower);
    if (daysMatch != null) _tbDaysCtrl.text = daysMatch.group(1)!;
    if (lower.contains('cough')) _tbSelectedSymptoms.add('cough');
    if (lower.contains('fever')) _tbSelectedSymptoms.add('fever');
    if (lower.contains('night sweat')) _tbSelectedSymptoms.add('night_sweats');
    if (lower.contains('fatigue') || lower.contains('tired')) _tbSelectedSymptoms.add('fatigue');
    _tbSelectedSymptoms = _tbSelectedSymptoms.toSet().toList();
    if (lower.contains('weight loss') || lower.contains('lost weight')) _tbWeightLoss = 'yes';
    if (lower.contains('no appetite') || lower.contains('appetite loss')) _tbAppetiteLoss = 'yes';
    _tbSummaryCtrl.text = original;
  }

  void _parsePesticideVoice(String lower, String original) {
    if (lower.contains('vomit')) _pestSelectedSymptoms.add('vomiting');
    if (lower.contains('dizziness') || lower.contains('dizzy')) _pestSelectedSymptoms.add('dizziness');
    if (lower.contains('headache')) _pestSelectedSymptoms.add('headache');
    if (lower.contains('blurred') || lower.contains('vision')) _pestSelectedSymptoms.add('blurred_vision');
    _pestSelectedSymptoms = _pestSelectedSymptoms.toSet().toList();
    final durMatch = RegExp(r'(\d+)\s*(?:hours?|minutes?|hrs?)').firstMatch(lower);
    if (durMatch != null) _pestDurationCtrl.text = durMatch.group(0)!;
    if (lower.contains('no glove') || lower.contains('no gear') || lower.contains('no protection')) {
      _pestGear = 'no';
    } else if (lower.contains('glove') || lower.contains('gear') || lower.contains('protection')) {
      _pestGear = 'yes';
    }
    final crops = ['cotton', 'wheat', 'rice', 'corn', 'maize', 'sugarcane'];
    for (final crop in crops) {
      if (lower.contains(crop)) { _pestCropCtrl.text = crop; break; }
    }
    _pestTextCtrl.text = original;
  }

  void _parseDfuVoice(String lower, String original) {
    if (lower.contains('high') || lower.contains('severe') || lower.contains('intense')) {
      _dfuPain = 'high';
    } else if (lower.contains('moderate') || lower.contains('medium')) {
      _dfuPain = 'moderate';
    } else if (lower.contains('low') || lower.contains('mild') || lower.contains('light')) {
      _dfuPain = 'low';
    }
    if (lower.contains('swelling') || lower.contains('swollen')) _dfuSwelling = 'yes';
    if (lower.contains('no swelling') || lower.contains('not swollen')) _dfuSwelling = 'no';
    final durMatch = RegExp(r'(\d+)\s*(?:days?|weeks?|months?)').firstMatch(lower);
    if (durMatch != null) _dfuDurationCtrl.text = durMatch.group(0)!;
  }

  // ─── Navigation ───────────────────────────────────────────────────────────

  void _goToForm() {
    if (_selectedPatient == null) {
      _snack('Please select a patient', isError: true); return;
    }
    if (_selectedDisease == null) {
      _snack('Please select a diagnosis type', isError: true); return;
    }
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
        'SenseAI Reminder: Please give ${_result!.patientName} '
        'the medication "$medName" starting at $time, '
        'every $_reminderInterval hours. - Sent by Health Worker';
    try {
      final Uri smsUri = Uri(scheme: 'sms', path: phone, queryParameters: {'body': message});
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
    _snack('Checklist saved!');
  }

  // ─── Submit ───────────────────────────────────────────────────────────────

  Future<void> _submitDiagnosis() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> inputs      = {};
      Map<String, dynamic> apiResponse = {};
      final bool online = ConnectivityService().isOnline;

      if (online) {
        switch (_selectedDisease!) {
          case DiseaseType.maternal:
            inputs = {
              'bleeding_level': _mBleedingLevel,
              'pulse':          int.tryParse(_mPulseCtrl.text) ?? 0,
              'bp':             _mBpCtrl.text.trim(),
              'weakness':       _mWeakness,
              'description':    _mDescCtrl.text.trim(),
              'language':       _selectedLanguage,
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
              'language':             _selectedLanguage,
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
              'language':        _selectedLanguage,
            };
            apiResponse = await ApiService.diagnosePesticide(inputs);
            break;

          case DiseaseType.dfu:
            if (_dfuImageFile == null) {
              _snack('Please capture a foot image first', isError: true);
              setState(() => _isLoading = false);
              return;
            }
            inputs = {
              'pain':     _dfuPain,
              'swelling': _dfuSwelling,
              'duration': _dfuDurationCtrl.text.trim(),
              'language': _selectedLanguage,
            };
            apiResponse = await ApiService.diagnoseDfu(
              image: File(_dfuImageFile!.path),
              pain: _dfuPain,
              swelling: _dfuSwelling,
              duration: _dfuDurationCtrl.text.trim(),
              language: _selectedLanguage,
            );
            break;
        }
        _wasOffline = false;

      } else {
        switch (_selectedDisease!) {
          case DiseaseType.maternal:
            inputs = {
              'bleeding_level': _mBleedingLevel,
              'pulse':          int.tryParse(_mPulseCtrl.text) ?? 0,
              'bp':             _mBpCtrl.text.trim(),
              'weakness':       _mWeakness,
              'description':    _mDescCtrl.text.trim(),
              'language':       _selectedLanguage,
            };
            apiResponse = ApiService.offlineMaternel(inputs);
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
              'language':             _selectedLanguage,
            };
            apiResponse = ApiService.offlineTb(inputs);
            break;

          case DiseaseType.pesticide:
            inputs = {
              'symptoms':        _pestSelectedSymptoms,
              'crop_type':       _pestCropCtrl.text.trim(),
              'recent_exposure': _pestExposure,
              'duration':        _pestDurationCtrl.text.trim(),
              'protective_gear': _pestGear,
              'text_input':      _pestTextCtrl.text.trim(),
              'language':        _selectedLanguage,
            };
            apiResponse = ApiService.offlinePesticide(inputs);
            break;

          case DiseaseType.dfu:
            inputs = {
              'pain':     _dfuPain,
              'swelling': _dfuSwelling,
              'duration': _dfuDurationCtrl.text.trim(),
              'language': _selectedLanguage,
            };
            apiResponse = ApiService.offlineDfu(inputs);
            break;
        }
        _wasOffline = true;
        await StorageService.addToSyncQueue(_selectedDisease!.label, inputs);
      }

      final record = DiagnosisRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        patientId: _selectedPatient!.id,
        patientName: _selectedPatient!.name,
        diseaseType: _selectedDisease!.label,
        inputs: inputs,
        apiResponse: apiResponse,
        timestamp: DateTime.now().toIso8601String(),
        checkedActions: const [],
      );
      await StorageService.saveDiagnosis(record);

      if (mounted) {
        final checklist = record.checklist;
        setState(() {
          _result        = record;
          _actionChecked = List.filled(checklist.length, false);
          _actionsSaved  = false;
          _step          = 2;
          _isLoading     = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _snack('Error: $e', isError: true);
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
            RuraxTopBar(
              title: 'New Diagnosis',
              showBack: true,
              onBack: () {
                if (_step > 0) {
                  setState(() { _step -= 1; _result = null; });
                } else {
                  Navigator.pop(context);
                }
              },
              onMicTap: _step == 1 ? (_isListening ? _stopVoiceInput : _startVoiceInput) : null,
              micActive: _isListening,
            ),
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
        onTap: (i) {
          if (i == 0) Navigator.popUntil(context, (r) => r.isFirst);
        },
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
          const Text('New Diagnosis',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700,
                  color: AppColors.textDark, letterSpacing: -0.5)),
          const SizedBox(height: 2),
          const Text('SELECT PATIENT & DISEASE',
              style: TextStyle(fontSize: 11, color: AppColors.textLight, letterSpacing: 1.2)),
          const SizedBox(height: 24),

          _sectionLabel('PATIENT'),
          const SizedBox(height: 8),
          if (_patients.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: AppColors.textHint),
                SizedBox(width: 8),
                Text('No patients registered yet.', style: TextStyle(color: AppColors.textMid)),
              ]),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<Patient>(
                  isExpanded: true,
                  hint: const Text('Select patient', style: TextStyle(color: AppColors.textHint)),
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
                    '${_selectedPatient!.name}  •  Age ${_selectedPatient!.age}  •  ${_selectedPatient!.gender}',
                    style: const TextStyle(fontSize: 13, color: AppColors.darkGreen,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 24),

          _sectionLabel('LANGUAGE'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: _selectedLanguage,
                items: const [
                  DropdownMenuItem(
                    value: 'english',
                    child: Row(children: [
                      Icon(Icons.language, color: AppColors.darkGreen, size: 18),
                      SizedBox(width: 10),
                      Text('English'),
                    ]),
                  ),
                  DropdownMenuItem(
                    value: 'hindi',
                    child: Row(children: [
                      Icon(Icons.language, color: AppColors.darkGreen, size: 18),
                      SizedBox(width: 10),
                      Text('हिन्दी (Hindi)'),
                    ]),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _selectedLanguage = v);
                },
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Diagnosis output will be returned in ${_selectedLanguage == 'hindi' ? 'Hindi' : 'English'}',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),

          const SizedBox(height: 24),
          _sectionLabel('DIAGNOSIS TYPE'),
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
              child: const Text('Continue',
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
            child: Text(d.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                color: selected ? d.color : AppColors.textDark)),
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
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.darkGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.darkGreen.withOpacity(0.2)),
            ),
            child: const Row(children: [
              Icon(Icons.mic_none, color: AppColors.darkGreen, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap the 🎤 mic icon next to any field to fill it by speaking',
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
              child: Text(_selectedDisease!.label,
                  style: TextStyle(color: _selectedDisease!.color,
                      fontWeight: FontWeight.w700, fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: AppColors.darkGreen.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.language, color: AppColors.darkGreen, size: 13),
                const SizedBox(width: 4),
                Text(
                  _selectedLanguage == 'hindi' ? 'हिन्दी' : 'English',
                  style: const TextStyle(color: AppColors.darkGreen,
                      fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ]),
            ),
          ]),
          const SizedBox(height: 6),
          Text(_selectedPatient!.name,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          Text('Age ${_selectedPatient!.age}  •  ${_selectedPatient!.gender}',
              style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
          const SizedBox(height: 24),
          const Text('PATIENT INPUTS',
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
                  : const Text('Run Diagnosis',
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
      _formLabel('Bleeding Level'), const SizedBox(height: 6),
      _chipSelector(options: ['light', 'moderate', 'heavy'],
          selected: _mBleedingLevel, onSelect: (v) => setState(() => _mBleedingLevel = v)),
      const SizedBox(height: 14),
      _formLabel('Pulse (bpm)'), const SizedBox(height: 6),
      _inputField(
        _mPulseCtrl, 'e.g. 110', TextInputType.number,
        voiceHint: 'Say the pulse rate e.g. "pulse 110" / "नब्ज़ 110"',
      ),
      const SizedBox(height: 14),
      _formLabel('Blood Pressure'), const SizedBox(height: 6),
      _inputField(
        _mBpCtrl, 'e.g. 90/60', TextInputType.text,
        voiceHint: 'Say BP e.g. "90 over 60" / "रक्तचाप 90 बटा 60"',
      ),
      const SizedBox(height: 14),
      _formLabel('Weakness'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'],
          selected: _mWeakness, onSelect: (v) => setState(() => _mWeakness = v)),
      const SizedBox(height: 14),
      _formLabel('Description'), const SizedBox(height: 6),
      _inputField(
        _mDescCtrl, 'Describe symptoms in detail...',
        TextInputType.multiline, maxLines: 3,
        voiceHint: 'Describe symptoms e.g. "Heavy bleeding since morning, feeling very weak" / "सुबह से भारी रक्तस्राव हो रहा है"',
      ),
    ],
  );

  Widget _tbForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _formLabel('Missed Doses'), const SizedBox(height: 6),
      _inputField(
        _tbMissedCtrl, 'e.g. 4', TextInputType.number,
        voiceHint: 'Say number of missed doses e.g. "missed 4 doses" / "4 खुराक छूट गई"',
      ),
      const SizedBox(height: 14),
      _formLabel('Days Since Last Dose'), const SizedBox(height: 6),
      _inputField(
        _tbDaysCtrl, 'e.g. 3', TextInputType.number,
        voiceHint: 'Say e.g. "3 days ago" / "3 दिन पहले"',
      ),
      const SizedBox(height: 14),
      _formLabel('Symptoms'), const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8,
          children: _tbAllSymptoms.map((s) {
            final sel = _tbSelectedSymptoms.contains(s);
            return GestureDetector(
              onTap: () => setState(() {
                sel ? _tbSelectedSymptoms.remove(s) : _tbSelectedSymptoms.add(s);
              }),
              child: _chipWidget(s.replaceAll('_', ' '), sel),
            );
          }).toList()),
      const SizedBox(height: 14),
      _formLabel('Weight Loss'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'],
          selected: _tbWeightLoss, onSelect: (v) => setState(() => _tbWeightLoss = v)),
      const SizedBox(height: 14),
      _formLabel('Appetite Loss'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'],
          selected: _tbAppetiteLoss, onSelect: (v) => setState(() => _tbAppetiteLoss = v)),
      const SizedBox(height: 14),
      _formLabel('Duration of Symptoms'), const SizedBox(height: 6),
      _inputField(
        _tbDurationCtrl, 'e.g. 3 weeks', TextInputType.text,
        voiceHint: 'Say e.g. "3 weeks" / "3 हफ्ते से"',
      ),
      const SizedBox(height: 14),
      _formLabel('Past Summary'), const SizedBox(height: 6),
      _inputField(
        _tbSummaryCtrl, 'Patient history notes...', TextInputType.multiline, maxLines: 3,
        voiceHint: 'Describe patient history e.g. "Started TB treatment 6 months ago" / "6 महीने पहले TB का इलाज शुरू हुआ था"',
      ),
    ],
  );

  Widget _pesticideForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _formLabel('Symptoms'), const SizedBox(height: 6),
      Wrap(spacing: 8, runSpacing: 8,
          children: _pestAllSymptoms.map((s) {
            final sel = _pestSelectedSymptoms.contains(s);
            return GestureDetector(
              onTap: () => setState(() {
                sel ? _pestSelectedSymptoms.remove(s) : _pestSelectedSymptoms.add(s);
              }),
              child: _chipWidget(s.replaceAll('_', ' '), sel),
            );
          }).toList()),
      const SizedBox(height: 14),
      _formLabel('Crop Type'), const SizedBox(height: 6),
      _inputField(
        _pestCropCtrl, 'e.g. cotton', TextInputType.text,
        voiceHint: 'Say crop name e.g. "cotton" / "कपास"',
      ),
      const SizedBox(height: 14),
      _formLabel('Recent Exposure'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'],
          selected: _pestExposure, onSelect: (v) => setState(() => _pestExposure = v)),
      const SizedBox(height: 14),
      _formLabel('Duration of Exposure'), const SizedBox(height: 6),
      _inputField(
        _pestDurationCtrl, 'e.g. 1 hour', TextInputType.text,
        voiceHint: 'Say e.g. "1 hour" / "1 घंटा"',
      ),
      const SizedBox(height: 14),
      _formLabel('Protective Gear Used'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'],
          selected: _pestGear, onSelect: (v) => setState(() => _pestGear = v)),
      const SizedBox(height: 14),
      _formLabel('Description'), const SizedBox(height: 6),
      _inputField(
        _pestTextCtrl, 'Describe what happened...', TextInputType.multiline, maxLines: 3,
        voiceHint: 'Describe the incident e.g. "Sprayed pesticide without mask for 2 hours" / "2 घंटे बिना मास्क के कीटनाशक छिड़का"',
      ),
    ],
  );

  Widget _dfuForm() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _formLabel('Foot Image'), const SizedBox(height: 8),
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
            Text('Tap to capture foot image',
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
      _formLabel('Pain Level'), const SizedBox(height: 6),
      _chipSelector(options: ['low', 'moderate', 'high'],
          selected: _dfuPain, onSelect: (v) => setState(() => _dfuPain = v)),
      const SizedBox(height: 14),
      _formLabel('Swelling Present'), const SizedBox(height: 6),
      _chipSelector(options: ['yes', 'no'],
          selected: _dfuSwelling, onSelect: (v) => setState(() => _dfuSwelling = v)),
      const SizedBox(height: 14),
      _formLabel('Duration'), const SizedBox(height: 6),
      _inputField(
        _dfuDurationCtrl, 'e.g. 5 days', TextInputType.text,
        voiceHint: 'Say e.g. "5 days" / "5 दिन से"',
      ),
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
          const Text('Diagnosis Result',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700,
                  color: AppColors.textDark, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(r.patientName, style: const TextStyle(fontSize: 14, color: AppColors.textLight)),

          if (_wasOffline) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(children: [
                Icon(Icons.wifi_off, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedLanguage == 'hindi'
                        ? 'ऑफलाइन मोड — स्थानीय स्कोरिंग इंजन द्वारा परिणाम। इंटरनेट मिलने पर डेटा सिंक होगा।'
                        : 'Offline mode — result from local scoring engine. Data queued to sync when online.',
                    style: TextStyle(fontSize: 12, color: Colors.orange.shade800, height: 1.4),
                  ),
                ),
              ]),
            ),
          ],

          const SizedBox(height: 16),
          RiskBadge(level: r.riskLevel, score: r.riskScore),
          const SizedBox(height: 16),

          _resultSection('Explanation', (r.apiResponse['explanation'] ?? '').toString()),
          _resultSection('Recommendation', r.recommendation),

          if (r.apiResponse.containsKey('ulcer_severity'))
            _resultSection('Ulcer Severity',
                r.apiResponse['ulcer_severity']?.toString() ?? ''),
          if (r.apiResponse.containsKey('infection_risk'))
            _resultSection('Infection Risk',
                r.apiResponse['infection_risk']?.toString() ?? ''),
          if (r.apiResponse.containsKey('relapse_risk'))
            _resultSection('Relapse Risk',
                r.apiResponse['relapse_risk']?.toString() ?? ''),

          if (r.apiResponse['emergency'] == true) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade400),
              ),
              child: Row(children: [
                Icon(Icons.emergency, color: Colors.red.shade700, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _selectedLanguage == 'hindi'
                        ? '🚨 आपातकाल! तुरंत 108 बुलाएं।'
                        : '🚨 Emergency! Call 108 immediately.',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: Colors.red.shade700),
                  ),
                ),
              ]),
            ),
          ],

          if (checklist.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(children: [
              const Expanded(
                child: Text('ACTION CHECKLIST',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                        color: AppColors.textLight, letterSpacing: 1.2)),
              ),
              if (_actionsSaved)
                const Row(children: [
                  Icon(Icons.check_circle, color: AppColors.darkGreen, size: 15),
                  SizedBox(width: 4),
                  Text('Saved', style: TextStyle(fontSize: 12,
                      color: AppColors.darkGreen, fontWeight: FontWeight.w600)),
                ]),
            ]),
            const SizedBox(height: 4),
            const Text("Tick completed actions — saved to this patient's history.",
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
                    size: 18, color: _actionsSaved ? AppColors.textHint : AppColors.darkGreen),
                label: Text(
                  _actionsSaved ? 'Checklist saved' : 'Save checklist progress',
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
                  const Text('MISSING DATA',
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
                      Text('Set Medication Reminder',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                              color: AppColors.textDark)),
                      SizedBox(height: 2),
                      Text("Send SMS reminder to patient's number",
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
                        Text('SMS will be sent to: ${_selectedPatient!.phone}',
                            style: const TextStyle(fontSize: 12, color: AppColors.darkGreen,
                                fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  const Text('Medication Name',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMid)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(color: AppColors.background,
                        borderRadius: BorderRadius.circular(10)),
                    child: TextField(
                      controller: _reminderMedCtrl,
                      style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                      decoration: const InputDecoration(
                        hintText: 'e.g. Oxytocin, Rifampicin...',
                        prefixIcon: Icon(Icons.medication_outlined, color: AppColors.textHint, size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Start Time',
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
                        hintText: 'Tap to pick time',
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
                  const Text('Repeat Every (hours)',
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
                            value: h, child: Text('Every $h hours'))).toList(),
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
              label: const Text('Finish',
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

  /// Text field with an optional mic button.
  /// Pass [voiceHint] to enable the per-field mic icon.
  Widget _inputField(
      TextEditingController ctrl,
      String hint,
      TextInputType type, {
        int maxLines = 1,
        String? voiceHint,
      }) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.end : CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: type,
              maxLines: maxLines,
              style: const TextStyle(fontSize: 14, color: AppColors.textDark),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textHint),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
            ),
          ),
          if (voiceHint != null) ...[
            const SizedBox(width: 4),
            Padding(
              padding: EdgeInsets.only(
                right: 6,
                bottom: maxLines > 1 ? 6 : 0,
              ),
              child: GestureDetector(
                onTap: () => _startFieldVoiceInput(
                  controller: ctrl,
                  hint: voiceHint,
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: (_activeVoiceController == ctrl && _isListening)
                        ? AppColors.darkGreen
                        : AppColors.darkGreen.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    (_activeVoiceController == ctrl && _isListening)
                        ? Icons.mic
                        : Icons.mic_none,
                    color: (_activeVoiceController == ctrl && _isListening)
                        ? Colors.white
                        : AppColors.darkGreen,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipSelector({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) =>
      Wrap(
        spacing: 8,
        children: options.map((o) => GestureDetector(
            onTap: () => onSelect(o),
            child: _chipWidget(o, selected == o))).toList(),
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