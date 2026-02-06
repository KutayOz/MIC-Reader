// MIC Reader App - Test Suite
//
// Run all tests: flutter test
// Run specific file: flutter test test/models/well_result_test.dart

import 'package:flutter_test/flutter_test.dart';

// Import all test files
import 'models/well_result_test.dart' as well_result_tests;
import 'models/mic_result_test.dart' as mic_result_tests;
import 'services/classification_test.dart' as classification_tests;
import 'providers/user_provider_test.dart' as user_provider_tests;
import 'providers/locale_provider_test.dart' as locale_provider_tests;

void main() {
  group('MIC Reader Tests', () {
    group('Models', () {
      well_result_tests.main();
      mic_result_tests.main();
    });

    group('Services', () {
      classification_tests.main();
    });

    group('Providers', () {
      user_provider_tests.main();
      locale_provider_tests.main();
    });
  });
}
