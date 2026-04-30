// lib/services/offline_diagnosis_engine.dart
//
// Mirrors the exact scoring logic from the Python backend prompts.
// Used when the device has no internet connectivity.

class OfflineDiagnosisEngine {
  // ─── MATERNAL ─────────────────────────────────────────────────────────────
  //
  // Bleeding:  low=10, medium=30, heavy=60
  // Pulse:     <100→5, 100–120→15, >120→30
  // BP:        >=100 systolic→5, 90–99→20, <90→40
  // Weakness:  no→5, yes→20
  // Cap 0–100
  // LOW<31, MEDIUM 31–60, HIGH 61–100

  static Map<String, dynamic> diagnoseMaternel(Map<String, dynamic> data,
      {String language = 'english'}) {
    final bool isHindi = language.toLowerCase() == 'hindi';

    int score = 0;
    final List<String> missing = [];
    final List<String> explanationParts = [];

    // 1. Bleeding
    final String bleeding =
    (data['bleeding_level'] ?? '').toString().toLowerCase();
    if (bleeding.isEmpty) {
      missing.add(isHindi ? 'रक्तस्राव स्तर' : 'bleeding_level');
    } else {
      final int b = bleeding == 'heavy'
          ? 60
          : bleeding == 'moderate'
          ? 30
          : 10;
      score += b;
      explanationParts.add(isHindi
          ? 'रक्तस्राव ($bleeding): +$b अंक'
          : 'Bleeding ($bleeding): +$b points');
    }

    // 2. Pulse
    final int pulse = int.tryParse(data['pulse']?.toString() ?? '') ?? -1;
    if (pulse < 0) {
      missing.add(isHindi ? 'नाड़ी (bpm)' : 'pulse');
    } else {
      final int p = pulse > 120
          ? 30
          : pulse >= 100
          ? 15
          : 5;
      score += p;
      explanationParts.add(isHindi
          ? 'नाड़ी ($pulse bpm): +$p अंक'
          : 'Pulse ($pulse bpm): +$p points');
    }

    // 3. Blood Pressure (systolic)
    final String bp = (data['bp'] ?? '').toString();
    if (bp.isEmpty) {
      missing.add(isHindi ? 'रक्तचाप' : 'blood_pressure');
    } else {
      final int? systolic =
      int.tryParse(bp.split('/').first.trim());
      if (systolic == null) {
        missing.add(isHindi ? 'रक्तचाप (अमान्य प्रारूप)' : 'blood_pressure (invalid format)');
      } else {
        final int bpScore = systolic < 90
            ? 40
            : systolic < 100
            ? 20
            : 5;
        score += bpScore;
        explanationParts.add(isHindi
            ? 'रक्तचाप ($bp): +$bpScore अंक'
            : 'Blood pressure ($bp): +$bpScore points');
      }
    }

    // 4. Weakness
    final String weakness =
    (data['weakness'] ?? '').toString().toLowerCase();
    if (weakness.isEmpty) {
      missing.add(isHindi ? 'कमज़ोरी' : 'weakness');
    } else {
      final int w = weakness == 'yes' ? 20 : 5;
      score += w;
      explanationParts.add(isHindi
          ? 'कमज़ोरी ($weakness): +$w अंक'
          : 'Weakness ($weakness): +$w points');
    }

    score = score.clamp(0, 100);

    final String level = score <= 30
        ? 'LOW'
        : score <= 60
        ? 'MEDIUM'
        : 'HIGH';

    final double confidence =
    missing.isEmpty ? 0.85 : missing.length == 1 ? 0.65 : 0.40;

    return {
      'risk_score': score,
      'risk_level': level,
      'recommendation': _maternalRec(level, isHindi),
      'confidence': confidence,
      'explanation': isHindi
          ? 'मूल्यांकन कारक: ${explanationParts.join(', ')}. कुल जोखिम स्कोर: $score/100.'
          : 'Scoring factors: ${explanationParts.join(', ')}. Total risk score: $score/100.',
      'missing_data': missing,
      'checklist': _maternalChecklist(level, isHindi),
    };
  }

  static String _maternalRec(String level, bool hindi) {
    if (hindi) {
      switch (level) {
        case 'HIGH':
          return 'तत्काल कार्रवाई आवश्यक! मरीज़ को तुरंत अस्पताल भेजें। ऑक्सीटोसिन दें और IV लाइन शुरू करें।';
        case 'MEDIUM':
          return 'मरीज़ की बारीकी से निगरानी करें। नाड़ी और रक्तचाप हर 15 मिनट में जाँचें। अगर स्थिति बिगड़े तो तुरंत रेफर करें।';
        default:
          return 'सामान्य निगरानी जारी रखें। हर 30 मिनट में स्थिति की जाँच करें।';
      }
    }
    switch (level) {
      case 'HIGH':
        return 'Immediate action required! Refer patient to hospital urgently. Administer oxytocin and start IV line.';
      case 'MEDIUM':
        return 'Monitor closely. Check pulse and BP every 15 minutes. Refer immediately if condition worsens.';
      default:
        return 'Continue routine monitoring. Check vitals every 30 minutes.';
    }
  }

  static List<String> _maternalChecklist(String level, bool hindi) {
    if (hindi) {
      if (level == 'HIGH') {
        return [
          'तुरंत 108 एम्बुलेंस बुलाएं',
          'मरीज़ को लेटा कर पैर ऊपर उठाएं',
          'ऑक्सीटोसिन 10 IU IM दें (यदि उपलब्ध हो)',
          'IV कैनुला लगाएं और नॉर्मल सेलाइन शुरू करें',
          'रक्तस्राव की मात्रा नोट करें',
          'हर 5 मिनट में नाड़ी और रक्तचाप जाँचें',
          'परिवार को सूचित करें',
          'अस्पताल को पहले से सूचित करें',
        ];
      } else if (level == 'MEDIUM') {
        return [
          'हर 15 मिनट में नाड़ी और BP मापें',
          'रक्तस्राव की मात्रा रिकॉर्ड करें',
          'मरीज़ को आराम करने दें',
          'ऑक्सीटोसिन तैयार रखें',
          'परिवार को सतर्क रखें',
          'यदि स्थिति बिगड़े तो तुरंत रेफर करें',
        ];
      }
      return [
        'हर 30 मिनट में जाँच करें',
        'रक्तस्राव की निगरानी करें',
        'हाइड्रेशन सुनिश्चित करें',
        'मरीज़ को आराम करने दें',
      ];
    }
    if (level == 'HIGH') {
      return [
        'Call 108 ambulance immediately',
        'Lay patient flat with legs elevated',
        'Administer Oxytocin 10 IU IM if available',
        'Insert IV cannula and start Normal Saline',
        'Record blood loss volume',
        'Check pulse and BP every 5 minutes',
        'Inform family members',
        'Pre-alert receiving hospital',
      ];
    } else if (level == 'MEDIUM') {
      return [
        'Measure pulse and BP every 15 minutes',
        'Record amount of bleeding',
        'Keep patient resting',
        'Keep Oxytocin ready',
        'Keep family on alert',
        'Refer immediately if condition worsens',
      ];
    }
    return [
      'Check every 30 minutes',
      'Monitor bleeding',
      'Ensure hydration',
      'Keep patient rested',
    ];
  }

  // ─── TB ───────────────────────────────────────────────────────────────────
  //
  // Missed doses: 0→5, 1–3→20, >3→40
  // Days since last dose: <3→5, 3–7→20, >7→35
  // Symptoms: cough+10, fever+10, night_sweats+15, fatigue+10
  // Weight loss yes→+15
  // Appetite loss yes→+10
  // Cap 100 | LOW<30, MEDIUM 30–60, HIGH>60
  // Relapse HIGH if missed>3 AND symptoms present

  static Map<String, dynamic> diagnoseTb(Map<String, dynamic> data,
      {String language = 'english'}) {
    final bool isHindi = language.toLowerCase() == 'hindi';

    int score = 0;
    final List<String> missing = [];
    final List<String> explanationParts = [];

    // Missed doses
    final int missed = int.tryParse(data['missed_doses']?.toString() ?? '') ?? -1;
    if (missed < 0) {
      missing.add(isHindi ? 'छूटी हुई खुराकें' : 'missed_doses');
    } else {
      final int m = missed == 0 ? 5 : missed <= 3 ? 20 : 40;
      score += m;
      explanationParts.add(isHindi
          ? 'छूटी खुराकें ($missed): +$m'
          : 'Missed doses ($missed): +$m');
    }

    // Days since last dose
    final int days = int.tryParse(data['days_since_last_dose']?.toString() ?? '') ?? -1;
    if (days < 0) {
      missing.add(isHindi ? 'अंतिम खुराक के बाद के दिन' : 'days_since_last_dose');
    } else {
      final int d = days < 3 ? 5 : days <= 7 ? 20 : 35;
      score += d;
      explanationParts.add(isHindi
          ? 'अंतिम खुराक ($days दिन पहले): +$d'
          : 'Days since last dose ($days): +$d');
    }

    // Symptoms
    final List symptoms = data['symptoms'] is List
        ? data['symptoms'] as List
        : ((data['symptoms']?.toString() ?? '').split(','));
    final symSet = symptoms.map((s) => s.toString().trim().toLowerCase()).toSet();

    if (symSet.isEmpty || (symSet.length == 1 && symSet.first.isEmpty)) {
      missing.add(isHindi ? 'लक्षण' : 'symptoms');
    } else {
      if (symSet.contains('cough')) { score += 10; explanationParts.add(isHindi ? 'खांसी: +10' : 'Cough: +10'); }
      if (symSet.contains('fever')) { score += 10; explanationParts.add(isHindi ? 'बुखार: +10' : 'Fever: +10'); }
      if (symSet.contains('night_sweats')) { score += 15; explanationParts.add(isHindi ? 'रात को पसीना: +15' : 'Night sweats: +15'); }
      if (symSet.contains('fatigue')) { score += 10; explanationParts.add(isHindi ? 'थकान: +10' : 'Fatigue: +10'); }
    }

    // Weight loss
    final String wl = (data['weight_loss'] ?? '').toString().toLowerCase();
    if (wl == 'yes') { score += 15; explanationParts.add(isHindi ? 'वजन घटना: +15' : 'Weight loss: +15'); }

    // Appetite loss
    final String al = (data['appetite_loss'] ?? '').toString().toLowerCase();
    if (al == 'yes') { score += 10; explanationParts.add(isHindi ? 'भूख न लगना: +10' : 'Appetite loss: +10'); }

    score = score.clamp(0, 100);

    final String level = score < 30 ? 'LOW' : score <= 60 ? 'MEDIUM' : 'HIGH';
    final bool relapseHigh = missed > 3 && symSet.isNotEmpty;
    final String relapseRisk = relapseHigh ? 'HIGH' : score > 50 ? 'MEDIUM' : 'LOW';
    final double confidence = missing.isEmpty ? 0.85 : missing.length == 1 ? 0.65 : 0.40;

    return {
      'risk_score': score,
      'risk_level': level,
      'relapse_risk': relapseRisk,
      'recommendation': _tbRec(level, isHindi),
      'confidence': confidence,
      'explanation': isHindi
          ? 'स्कोरिंग कारक: ${explanationParts.join(', ')}. कुल: $score/100.'
          : 'Scoring factors: ${explanationParts.join(', ')}. Total: $score/100.',
      'missing_data': missing,
      'checklist': _tbChecklist(level, isHindi),
    };
  }

  static String _tbRec(String level, bool hindi) {
    if (hindi) {
      switch (level) {
        case 'HIGH':
          return 'तुरंत TB अधिकारी को सूचित करें। DOTS पर्यवेक्षण बढ़ाएं। थूक की जांच और छाती का X-ray करवाएं।';
        case 'MEDIUM':
          return 'दैनिक DOTS पर्यवेक्षण करें। परिवार को डॉट्स देखभालकर्ता बनाएं। अगले 3 दिनों में पुनः जाँच करें।';
        default:
          return 'नियमित DOTS जारी रखें। महीने में एक बार अनुवर्ती कार्रवाई करें।';
      }
    }
    switch (level) {
      case 'HIGH':
        return 'Notify TB officer immediately. Increase DOTS supervision. Order sputum test and chest X-ray.';
      case 'MEDIUM':
        return 'Daily DOTS supervision. Assign family member as DOTS caregiver. Re-assess in 3 days.';
      default:
        return 'Continue regular DOTS. Monthly follow-up.';
    }
  }

  static List<String> _tbChecklist(String level, bool hindi) {
    if (hindi) {
      if (level == 'HIGH') {
        return [
          'TB अधिकारी को तुरंत सूचित करें',
          'थूक परीक्षण के लिए नमूना लें',
          'छाती का X-ray करवाएं',
          'DOTS सुपरवाइज़र नियुक्त करें',
          'दवा प्रतिरोध की जांच करें',
          'परिवार की स्क्रीनिंग करें',
          'दैनिक घर दौरा शुरू करें',
        ];
      } else if (level == 'MEDIUM') {
        return [
          'दैनिक DOTS निगरानी शुरू करें',
          'परिवार के सदस्य को प्रशिक्षित करें',
          '3 दिन बाद पुनः मूल्यांकन करें',
          'खुराक का रिकॉर्ड रखें',
          'लक्षणों की निगरानी करें',
        ];
      }
      return [
        'मासिक अनुवर्ती कार्रवाई जारी रखें',
        'DOTS अनुपालन की जांच करें',
        'उचित पोषण सुनिश्चित करें',
      ];
    }
    if (level == 'HIGH') {
      return [
        'Notify TB officer immediately',
        'Collect sputum sample for testing',
        'Order chest X-ray',
        'Assign dedicated DOTS supervisor',
        'Check for drug resistance',
        'Screen family members',
        'Begin daily home visits',
      ];
    } else if (level == 'MEDIUM') {
      return [
        'Start daily DOTS supervision',
        'Train a family member as caregiver',
        'Re-assess after 3 days',
        'Maintain dose records',
        'Monitor symptoms',
      ];
    }
    return [
      'Continue monthly follow-up',
      'Verify DOTS compliance',
      'Ensure adequate nutrition',
    ];
  }

  // ─── PESTICIDE ────────────────────────────────────────────────────────────
  //
  // Symptoms: vomiting+25, dizziness+15, headache+10, blurred_vision+20
  // Exposure yes→+30
  // Gear no→+20, yes→+5
  // Duration >2hr→+20, 30min–2hr→+10, <30min→+5
  // Cap 100 | LOW<31, MEDIUM 31–60, HIGH 61–80, CRITICAL 81–100
  // Emergency: vomiting+exposure OR score>70

  static Map<String, dynamic> diagnosePesticide(Map<String, dynamic> data,
      {String language = 'english'}) {
    final bool isHindi = language.toLowerCase() == 'hindi';

    int score = 0;
    final List<String> missing = [];
    final List<String> explanationParts = [];

    // Symptoms
    final List symptoms = data['symptoms'] is List
        ? data['symptoms'] as List
        : ((data['symptoms']?.toString() ?? '').split(','));
    final symSet = symptoms.map((s) => s.toString().trim().toLowerCase()).toSet();

    if (symSet.isEmpty || (symSet.length == 1 && symSet.first.isEmpty)) {
      missing.add(isHindi ? 'लक्षण' : 'symptoms');
    } else {
      if (symSet.contains('vomiting')) { score += 25; explanationParts.add(isHindi ? 'उल्टी: +25' : 'Vomiting: +25'); }
      if (symSet.contains('dizziness')) { score += 15; explanationParts.add(isHindi ? 'चक्कर: +15' : 'Dizziness: +15'); }
      if (symSet.contains('headache')) { score += 10; explanationParts.add(isHindi ? 'सिरदर्द: +10' : 'Headache: +10'); }
      if (symSet.contains('blurred_vision')) { score += 20; explanationParts.add(isHindi ? 'धुंधली दृष्टि: +20' : 'Blurred vision: +20'); }
    }

    // Exposure
    final String exposure = (data['recent_exposure'] ?? '').toString().toLowerCase();
    if (exposure.isEmpty) {
      missing.add(isHindi ? 'हालिया संपर्क' : 'recent_exposure');
    } else {
      final int e = exposure == 'yes' ? 30 : 0;
      score += e;
      if (e > 0) explanationParts.add(isHindi ? 'हालिया कीटनाशक संपर्क: +$e' : 'Recent exposure: +$e');
    }

    // Protective gear
    final String gear = (data['protective_gear'] ?? '').toString().toLowerCase();
    if (gear.isEmpty) {
      missing.add(isHindi ? 'सुरक्षात्मक उपकरण' : 'protective_gear');
    } else {
      final int g = gear == 'no' ? 20 : 5;
      score += g;
      explanationParts.add(isHindi
          ? 'सुरक्षा उपकरण ($gear): +$g'
          : 'Protective gear ($gear): +$g');
    }

    // Duration (parse hours/minutes from string like "1 hour", "45 minutes")
    final String durStr = (data['duration'] ?? '').toString().toLowerCase();
    if (durStr.isEmpty) {
      missing.add(isHindi ? 'संपर्क की अवधि' : 'duration');
    } else {
      final double hours = _parseDurationToHours(durStr);
      final int d = hours > 2 ? 20 : hours >= 0.5 ? 10 : 5;
      score += d;
      explanationParts.add(isHindi ? 'अवधि ($durStr): +$d' : 'Duration ($durStr): +$d');
    }

    score = score.clamp(0, 100);

    final bool emergency = (symSet.contains('vomiting') && exposure == 'yes') || score > 70;
    final String level = score <= 30
        ? 'LOW'
        : score <= 60
        ? 'MEDIUM'
        : score <= 80
        ? 'HIGH'
        : 'CRITICAL';

    final double confidence = missing.isEmpty ? 0.85 : missing.length <= 1 ? 0.65 : 0.40;

    return {
      'risk_score': score,
      'risk_level': level,
      'poisoning_probability': score,
      'recommendation': _pesticideRec(level, isHindi),
      'emergency': emergency,
      'confidence': confidence,
      'explanation': isHindi
          ? 'स्कोरिंग कारक: ${explanationParts.join(', ')}. कुल: $score/100.'
          : 'Scoring factors: ${explanationParts.join(', ')}. Total: $score/100.',
      'missing_data': missing,
      'checklist': _pesticideChecklist(level, emergency, isHindi),
    };
  }

  static double _parseDurationToHours(String s) {
    final hrMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hour|hr)').firstMatch(s);
    final minMatch = RegExp(r'(\d+(?:\.\d+)?)\s*min').firstMatch(s);
    double total = 0;
    if (hrMatch != null) total += double.tryParse(hrMatch.group(1)!) ?? 0;
    if (minMatch != null) total += (double.tryParse(minMatch.group(1)!) ?? 0) / 60;
    if (total == 0) total = double.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '0') ?? 0;
    return total;
  }

  static String _pesticideRec(String level, bool hindi) {
    if (hindi) {
      switch (level) {
        case 'CRITICAL':
          return 'जीवन-संकट आपातकाल! तुरंत 108 बुलाएं। मरीज़ को ताज़ी हवा में ले जाएं। दूषित कपड़े हटाएं।';
        case 'HIGH':
          return 'तुरंत नज़दीकी अस्पताल रेफर करें। त्वचा और आँखों को साफ पानी से धोएं। उल्टी न कराएं।';
        case 'MEDIUM':
          return 'ताज़ी हवा में ले जाएं। त्वचा धोएं। 2 घंटे निगरानी रखें। यदि खराब हो तो रेफर करें।';
        default:
          return '4 घंटे आराम और निगरानी। ताज़ा पानी और तरल पदार्थ दें।';
      }
    }
    switch (level) {
      case 'CRITICAL':
        return 'Life-threatening emergency! Call 108 immediately. Move to fresh air. Remove contaminated clothing.';
      case 'HIGH':
        return 'Refer to hospital immediately. Wash skin and eyes with clean water. Do not induce vomiting.';
      case 'MEDIUM':
        return 'Move to fresh air. Wash skin. Monitor for 2 hours. Refer if worsens.';
      default:
        return 'Rest and monitor for 4 hours. Give fresh water and fluids.';
    }
  }

  static List<String> _pesticideChecklist(String level, bool emergency, bool hindi) {
    if (hindi) {
      final base = <String>[
        'मरीज़ को ताज़ी हवा में ले जाएं',
        'दूषित कपड़े और जूते हटाएं',
        'साबुन और पानी से त्वचा धोएं',
        'कीटनाशक का नाम/लेबल नोट करें',
      ];
      if (emergency) {
        return [
          '🚨 तुरंत 108 एम्बुलेंस बुलाएं',
          ...base,
          'उल्टी न कराएं जब तक डॉक्टर न कहे',
          'आँखें खुले पानी से 15 मिनट धोएं',
          'मरीज़ को अकेला न छोड़ें',
          'जहरीले पदार्थ का कंटेनर अस्पताल साथ ले जाएं',
        ];
      } else if (level == 'MEDIUM' || level == 'HIGH') {
        return [
          ...base,
          '2 घंटे लक्षणों की निगरानी करें',
          'ORS घोल दें',
          'यदि उल्टी/चक्कर बढ़े तो तुरंत रेफर करें',
        ];
      }
      return [...base, '4 घंटे आराम', 'पर्याप्त पानी पिलाएं'];
    }
    final base = <String>[
      'Move patient to fresh air immediately',
      'Remove contaminated clothes and shoes',
      'Wash skin with soap and water for 15 min',
      'Note the pesticide name/label',
    ];
    if (emergency) {
      return [
        '🚨 Call 108 ambulance immediately',
        ...base,
        'Do NOT induce vomiting unless instructed by doctor',
        'Flush eyes with clean water for 15 minutes',
        'Do not leave patient unattended',
        'Bring pesticide container to hospital',
      ];
    } else if (level == 'MEDIUM' || level == 'HIGH') {
      return [
        ...base,
        'Monitor symptoms for 2 hours',
        'Give ORS solution',
        'Refer immediately if vomiting/dizziness increases',
      ];
    }
    return [...base, 'Rest for 4 hours', 'Give plenty of water'];
  }

  // ─── DFU ─────────────────────────────────────────────────────────────────
  //
  // (Offline: no image analysis — score from pain/swelling/duration only)
  // Pain: low→5, moderate→15, high→25
  // Swelling: no→5, yes→20
  // Duration: <3d→5, 3–7d→15, >7d→30
  // No image → image severity omitted (noted in missing_data)
  // Cap 100 | LOW<31, MEDIUM 31–60, HIGH 61–80, CRITICAL 81–100

  static Map<String, dynamic> diagnoseDfu(Map<String, dynamic> data,
      {String language = 'english'}) {
    final bool isHindi = language.toLowerCase() == 'hindi';

    int score = 0;
    final List<String> missing = [
      isHindi
          ? 'पैर की छवि (ऑफलाइन में उपलब्ध नहीं — छवि विश्लेषण छोड़ा गया)'
          : 'foot_image (unavailable offline — image analysis skipped)',
    ];
    final List<String> explanationParts = [];

    // Pain
    final String pain = (data['pain'] ?? '').toString().toLowerCase();
    if (pain.isEmpty) {
      missing.add(isHindi ? 'दर्द स्तर' : 'pain');
    } else {
      final int p = pain == 'high' ? 25 : pain == 'moderate' ? 15 : 5;
      score += p;
      explanationParts.add(isHindi ? 'दर्द ($pain): +$p' : 'Pain ($pain): +$p');
    }

    // Swelling
    final String swelling = (data['swelling'] ?? '').toString().toLowerCase();
    if (swelling.isEmpty) {
      missing.add(isHindi ? 'सूजन' : 'swelling');
    } else {
      final int s = swelling == 'yes' ? 20 : 5;
      score += s;
      explanationParts.add(isHindi ? 'सूजन ($swelling): +$s' : 'Swelling ($swelling): +$s');
    }

    // Duration
    final String durStr = (data['duration'] ?? '').toString().toLowerCase();
    if (durStr.isEmpty) {
      missing.add(isHindi ? 'अवधि' : 'duration');
    } else {
      final int days = _parseDurationToDays(durStr);
      final int d = days < 3 ? 5 : days <= 7 ? 15 : 30;
      score += d;
      explanationParts.add(isHindi ? 'अवधि ($durStr): +$d' : 'Duration ($durStr): +$d');
    }

    score = score.clamp(0, 100);

    final String level = score <= 30
        ? 'LOW'
        : score <= 60
        ? 'MEDIUM'
        : score <= 80
        ? 'HIGH'
        : 'CRITICAL';

    final String ulcerSeverity = level == 'LOW'
        ? 'Mild'
        : level == 'MEDIUM'
        ? 'Moderate'
        : 'Severe';

    final String infectionRisk = score > 60 ? 'HIGH' : score > 35 ? 'MEDIUM' : 'LOW';
    final double confidence = 0.55; // always lower without image

    return {
      'risk_score': score,
      'risk_level': level,
      'ulcer_severity': ulcerSeverity,
      'infection_risk': infectionRisk,
      'recommendation': _dfuRec(level, isHindi),
      'confidence': confidence,
      'explanation': isHindi
          ? 'ऑफलाइन मूल्यांकन (छवि विश्लेषण के बिना). कारक: ${explanationParts.join(', ')}. कुल: $score/100.'
          : 'Offline assessment (without image analysis). Factors: ${explanationParts.join(', ')}. Total: $score/100.',
      'missing_data': missing,
      'checklist': _dfuChecklist(level, isHindi),
    };
  }

  static int _parseDurationToDays(String s) {
    final weekMatch = RegExp(r'(\d+)\s*week').firstMatch(s);
    final dayMatch  = RegExp(r'(\d+)\s*day').firstMatch(s);
    final monMatch  = RegExp(r'(\d+)\s*month').firstMatch(s);
    if (monMatch != null)  return (int.tryParse(monMatch.group(1)!) ?? 1) * 30;
    if (weekMatch != null) return (int.tryParse(weekMatch.group(1)!) ?? 1) * 7;
    if (dayMatch != null)  return int.tryParse(dayMatch.group(1)!) ?? 1;
    return int.tryParse(RegExp(r'\d+').firstMatch(s)?.group(0) ?? '1') ?? 1;
  }

  static String _dfuRec(String level, bool hindi) {
    if (hindi) {
      switch (level) {
        case 'CRITICAL':
          return 'तुरंत अस्पताल रेफर करें। अंग-विच्छेद का जोखिम। IV एंटीबायोटिक की आवश्यकता हो सकती है।';
        case 'HIGH':
          return '24 घंटों में डॉक्टर के पास ले जाएं। घाव की ड्रेसिंग करें। वजन न डालने दें।';
        case 'MEDIUM':
          return 'घाव साफ करें और ड्रेसिंग बदलें। 3 दिन में डॉक्टर को दिखाएं। जूते न पहनाएं।';
        default:
          return 'नियमित घाव देखभाल करें। सफाई रखें। सप्ताह में दोबारा जाँच करें।';
      }
    }
    switch (level) {
      case 'CRITICAL':
        return 'Refer to hospital immediately. Risk of amputation. IV antibiotics may be required.';
      case 'HIGH':
        return 'Take to doctor within 24 hours. Dress wound properly. Keep off weight.';
      case 'MEDIUM':
        return 'Clean wound and change dressing. Show to doctor in 3 days. No footwear on wound.';
      default:
        return 'Regular wound care. Keep clean. Re-check in one week.';
    }
  }

  static List<String> _dfuChecklist(String level, bool hindi) {
    if (hindi) {
      if (level == 'CRITICAL' || level == 'HIGH') {
        return [
          '🚨 तुरंत अस्पताल रेफर करें',
          'घाव को साफ कपड़े से ढकें',
          'पैर पर वजन न डालने दें',
          'रक्त शर्करा स्तर जाँचें',
          'संक्रमण के संकेत नोट करें (लाल, पस, बदबू)',
          'मधुमेह दवाई जारी रखने को कहें',
          'ऑनलाइन होने पर छवि के साथ पुनः जाँच करें',
        ];
      } else if (level == 'MEDIUM') {
        return [
          'नमक के पानी से घाव साफ करें',
          'साफ ड्रेसिंग लगाएं',
          'तंग जूते न पहनाएं',
          '3 दिन में डॉक्टर को दिखाएं',
          'रक्त शर्करा नियंत्रण की जाँच करें',
          'ऑनलाइन होने पर पूर्ण मूल्यांकन करें',
        ];
      }
      return [
        'घाव को प्रतिदिन साफ करें',
        'सूखी और साफ ड्रेसिंग रखें',
        'सप्ताह में पुनः जाँच करें',
        'रक्त शर्करा की निगरानी करें',
      ];
    }
    if (level == 'CRITICAL' || level == 'HIGH') {
      return [
        '🚨 Refer to hospital immediately',
        'Cover wound with clean cloth',
        'Keep all weight off the foot',
        'Check blood sugar levels',
        'Note infection signs (redness, pus, odor)',
        'Continue diabetes medication',
        'Perform full image assessment when online',
      ];
    } else if (level == 'MEDIUM') {
      return [
        'Clean wound with saline water',
        'Apply clean dressing',
        'Avoid tight footwear',
        'Show to doctor within 3 days',
        'Check blood sugar control',
        'Perform full assessment when back online',
      ];
    }
    return [
      'Clean wound daily',
      'Keep dressing dry and clean',
      'Re-check in one week',
      'Monitor blood sugar',
    ];
  }
}

