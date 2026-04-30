import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider extends ChangeNotifier {
  static const _key = 'locale';

  Locale _locale = const Locale('en');
  Locale get locale => _locale;

  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'hi': 'हिंदी',
    // 'mr': 'मराठी',
    // 'ta': 'தமிழ்',
    // 'te': 'తెలుగు',
    // 'kn': 'ಕನ್ನಡ',
    // 'gu': 'ગુજરાતી',
    // 'bn': 'বাংলা',
    // 'pa': 'ਪੰਜਾਬੀ',
    // 'ml': 'മലയാളം',
  };

  LanguageProvider() {
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'en';
    _locale = Locale(code);
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    _locale = Locale(code);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, code);
    notifyListeners();
  }

  String get currentLanguageName =>
      supportedLanguages[_locale.languageCode] ?? 'English';

  /// Returns true when Hindi is the active language.
  bool get isHindi => _locale.languageCode == 'hi';

  /// Returns true when English is the active language.
  bool get isEnglish => _locale.languageCode == 'en';
}