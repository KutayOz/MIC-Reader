import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mic_reader/providers/user_provider.dart';

void main() {
  group('UserProvider', () {
    setUp(() {
      // Set up mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
    });

    test('should have correct initial state', () {
      final provider = UserProvider();

      expect(provider.name, null);
      expect(provider.institution, null);
      expect(provider.isFirstRun, true);
      expect(provider.isInitialized, false);
    });

    test('init should load saved data', () async {
      // Pre-populate SharedPreferences
      SharedPreferences.setMockInitialValues({
        'user_name': 'Dr. Test',
        'user_institution': 'Test Hospital',
        'is_first_run': false,
      });

      final provider = UserProvider();
      await provider.init();

      expect(provider.name, 'Dr. Test');
      expect(provider.institution, 'Test Hospital');
      expect(provider.isFirstRun, false);
      expect(provider.isInitialized, true);
    });

    test('init should handle empty SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = UserProvider();
      await provider.init();

      expect(provider.name, null);
      expect(provider.institution, null);
      expect(provider.isFirstRun, true);
      expect(provider.isInitialized, true);
    });

    test('init should only run once', () async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'First',
      });

      final provider = UserProvider();
      await provider.init();
      expect(provider.name, 'First');

      // Manually change the value in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', 'Second');

      // Call init again - should not reload
      await provider.init();
      expect(provider.name, 'First'); // Still the first value
    });

    test('setUser should save and persist data', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = UserProvider();
      await provider.setUser(name: 'Dr. Smith', institution: 'City Hospital');

      expect(provider.name, 'Dr. Smith');
      expect(provider.institution, 'City Hospital');
      expect(provider.isFirstRun, false);

      // Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_name'), 'Dr. Smith');
      expect(prefs.getString('user_institution'), 'City Hospital');
      expect(prefs.getBool('is_first_run'), false);
    });

    test('setUser should handle null institution', () async {
      SharedPreferences.setMockInitialValues({
        'user_institution': 'Old Hospital',
      });

      final provider = UserProvider();
      await provider.setUser(name: 'Dr. Jones', institution: null);

      expect(provider.name, 'Dr. Jones');
      expect(provider.institution, null);

      // Verify institution was removed
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_institution'), null);
    });

    test('updateName should update and persist', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = UserProvider();
      await provider.setUser(name: 'Original Name');
      await provider.updateName('New Name');

      expect(provider.name, 'New Name');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_name'), 'New Name');
    });

    test('updateInstitution should update and persist', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = UserProvider();
      await provider.setUser(name: 'Dr. Test');
      await provider.updateInstitution('New Hospital');

      expect(provider.institution, 'New Hospital');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_institution'), 'New Hospital');
    });

    test('completeOnboarding should set isFirstRun to false', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = UserProvider();
      expect(provider.isFirstRun, true);

      await provider.completeOnboarding();

      expect(provider.isFirstRun, false);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('is_first_run'), false);
    });

    test('should notify listeners on changes', () async {
      SharedPreferences.setMockInitialValues({});

      final provider = UserProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.init();
      expect(notifyCount, 1);

      await provider.setUser(name: 'Test');
      expect(notifyCount, 2);

      await provider.updateName('New');
      expect(notifyCount, 3);

      await provider.updateInstitution('Hospital');
      expect(notifyCount, 4);

      await provider.completeOnboarding();
      expect(notifyCount, 5);
    });
  });
}
