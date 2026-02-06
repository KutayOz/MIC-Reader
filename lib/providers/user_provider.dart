import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProvider extends ChangeNotifier {
  static const String _keyName = 'user_name';
  static const String _keyInstitution = 'user_institution';
  static const String _keyFirstRun = 'is_first_run';
  static const String _keyAutoSave = 'auto_save_enabled';

  String? _name;
  String? _institution;
  bool _isFirstRun = true;
  bool _isInitialized = false;
  bool _autoSaveEnabled = true; // Default: ON

  String? get name => _name;
  String? get institution => _institution;
  bool get isFirstRun => _isFirstRun;
  bool get isInitialized => _isInitialized;
  bool get autoSaveEnabled => _autoSaveEnabled;

  /// Initialize provider by loading saved data
  Future<void> init() async {
    if (_isInitialized) return;

    final prefs = await SharedPreferences.getInstance();

    _name = prefs.getString(_keyName);
    _institution = prefs.getString(_keyInstitution);
    _isFirstRun = prefs.getBool(_keyFirstRun) ?? true;
    _autoSaveEnabled = prefs.getBool(_keyAutoSave) ?? true;

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setUser({required String name, String? institution}) async {
    _name = name;
    _institution = institution;
    _isFirstRun = false;

    // Persist to storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);
    if (institution != null) {
      await prefs.setString(_keyInstitution, institution);
    } else {
      await prefs.remove(_keyInstitution);
    }
    await prefs.setBool(_keyFirstRun, false);

    notifyListeners();
  }

  Future<void> updateName(String name) async {
    _name = name;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyName, name);

    notifyListeners();
  }

  Future<void> updateInstitution(String? institution) async {
    _institution = institution;

    final prefs = await SharedPreferences.getInstance();
    if (institution != null) {
      await prefs.setString(_keyInstitution, institution);
    } else {
      await prefs.remove(_keyInstitution);
    }

    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _isFirstRun = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFirstRun, false);

    notifyListeners();
  }

  Future<void> setAutoSaveEnabled(bool value) async {
    _autoSaveEnabled = value;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAutoSave, value);

    notifyListeners();
  }
}
