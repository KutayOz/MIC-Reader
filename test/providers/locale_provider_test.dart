import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mic_reader/providers/locale_provider.dart';

void main() {
  group('LocaleProvider', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should have correct initial state', () {
      final provider = LocaleProvider();

      expect(provider.locale, const Locale('en'));
      expect(provider.isInitialized, false);
    });

    test('init should load saved locale', () async {
      SharedPreferences.setMockInitialValues({
        'locale_code': 'tr',
      });

      final provider = LocaleProvider();
      await provider.init();

      expect(provider.locale, const Locale('tr'));
      expect(provider.isInitialized, true);
    });

    test('init should handle empty SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = LocaleProvider();
      await provider.init();

      expect(provider.locale, const Locale('en')); // Default
      expect(provider.isInitialized, true);
    });

    test('init should ignore invalid locale codes', () async {
      SharedPreferences.setMockInitialValues({
        'locale_code': 'fr', // Not supported
      });

      final provider = LocaleProvider();
      await provider.init();

      expect(provider.locale, const Locale('en')); // Fallback to default
    });

    test('init should only run once', () async {
      SharedPreferences.setMockInitialValues({
        'locale_code': 'tr',
      });

      final provider = LocaleProvider();
      await provider.init();
      expect(provider.locale, const Locale('tr'));

      // Change SharedPreferences directly
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('locale_code', 'en');

      // Call init again - should not reload
      await provider.init();
      expect(provider.locale, const Locale('tr')); // Still Turkish
    });

    test('setLocale should update and persist', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = LocaleProvider();
      await provider.setLocale(const Locale('tr'));

      expect(provider.locale, const Locale('tr'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('locale_code'), 'tr');
    });

    test('setLocale should reject unsupported locales', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = LocaleProvider();
      await provider.setLocale(const Locale('fr')); // Not supported

      expect(provider.locale, const Locale('en')); // Still default
    });

    test('setLocaleFromCode should work with valid codes', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = LocaleProvider();

      await provider.setLocaleFromCode('tr');
      expect(provider.locale, const Locale('tr'));

      await provider.setLocaleFromCode('en');
      expect(provider.locale, const Locale('en'));
    });

    test('should notify listeners on changes', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = LocaleProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.init();
      expect(notifyCount, 1);

      await provider.setLocale(const Locale('tr'));
      expect(notifyCount, 2);

      await provider.setLocaleFromCode('en');
      expect(notifyCount, 3);
    });

    test('should support English and Turkish', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = LocaleProvider();

      // English
      await provider.setLocaleFromCode('en');
      expect(provider.locale.languageCode, 'en');

      // Turkish
      await provider.setLocaleFromCode('tr');
      expect(provider.locale.languageCode, 'tr');
    });
  });
}
