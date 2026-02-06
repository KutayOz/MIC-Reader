import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  static const String _keyLocale = 'locale_code';

  Locale _locale = const Locale('en');
  bool _isInitialized = false;

  Locale get locale => _locale;
  bool get isInitialized => _isInitialized;

  /// Initialize provider by loading saved locale
  Future<void> init() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();
    final savedCode = prefs.getString(_keyLocale);

    if (savedCode != null && ['en', 'tr'].contains(savedCode)) {
      _locale = Locale(savedCode);
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (!['en', 'tr'].contains(locale.languageCode)) return;
    _locale = locale;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLocale, locale.languageCode);

    notifyListeners();
  }

  Future<void> setLocaleFromCode(String languageCode) async {
    await setLocale(Locale(languageCode));
  }
}
