// Test script for EUCAST interpretation
// Verifies breakpoint logic works correctly
//
// Usage: dart run bin/test_interpretation.dart

import '../lib/core/constants/drug_concentrations.dart';
import '../lib/core/constants/eucast_breakpoints.dart';
import '../lib/data/models/mic_result.dart';
import '../lib/data/models/organism.dart';
import '../lib/services/interpretation_service.dart';

void main() {
  print('=' * 60);
  print('EUCAST Interpretation Test Script');
  print('=' * 60);
  print('');

  // Test cases from EUCAST table
  final testCases = <_TestCase>[
    // C. albicans - Fluconazole (S ≤ 2, R > 4)
    _TestCase(Organism.cAlbicans, Antifungal.FLU, 1.0, Interpretation.susceptible, 'S'),
    _TestCase(Organism.cAlbicans, Antifungal.FLU, 2.0, Interpretation.susceptible, 'S'),
    _TestCase(Organism.cAlbicans, Antifungal.FLU, 3.0, Interpretation.intermediate, 'I'),
    _TestCase(Organism.cAlbicans, Antifungal.FLU, 4.0, Interpretation.intermediate, 'I'),
    _TestCase(Organism.cAlbicans, Antifungal.FLU, 8.0, Interpretation.resistant, 'R'),
    _TestCase(Organism.cAlbicans, Antifungal.FLU, 64.0, Interpretation.resistant, 'R'),

    // C. albicans - Voriconazole (S ≤ 0.06, R > 0.25)
    _TestCase(Organism.cAlbicans, Antifungal.VOR, 0.032, Interpretation.susceptible, 'S'),
    _TestCase(Organism.cAlbicans, Antifungal.VOR, 0.06, Interpretation.susceptible, 'S'),
    _TestCase(Organism.cAlbicans, Antifungal.VOR, 0.125, Interpretation.intermediate, 'I'),
    _TestCase(Organism.cAlbicans, Antifungal.VOR, 0.25, Interpretation.intermediate, 'I'),
    _TestCase(Organism.cAlbicans, Antifungal.VOR, 0.5, Interpretation.resistant, 'R'),

    // C. albicans - Amphotericin B (S ≤ 1, R > 1)
    _TestCase(Organism.cAlbicans, Antifungal.AMB, 0.5, Interpretation.susceptible, 'S'),
    _TestCase(Organism.cAlbicans, Antifungal.AMB, 1.0, Interpretation.susceptible, 'S'),
    _TestCase(Organism.cAlbicans, Antifungal.AMB, 2.0, Interpretation.resistant, 'R'),

    // C. albicans - Caspofungin (IE - Note 2)
    _TestCase(Organism.cAlbicans, Antifungal.CAS, 0.5, Interpretation.ie, 'IE'),

    // C. guilliermondii - All IE
    _TestCase(Organism.cGuilliermondii, Antifungal.FLU, 1.0, Interpretation.ie, 'IE'),
    _TestCase(Organism.cGuilliermondii, Antifungal.VOR, 0.06, Interpretation.ie, 'IE'),

    // C. parapsilosis - Anidulafungin (S ≤ 4, R > 4)
    _TestCase(Organism.cParapsilosis, Antifungal.AND, 2.0, Interpretation.susceptible, 'S'),
    _TestCase(Organism.cParapsilosis, Antifungal.AND, 4.0, Interpretation.susceptible, 'S'),
    _TestCase(Organism.cParapsilosis, Antifungal.AND, 8.0, Interpretation.resistant, 'R'),

    // C. auris - Fluconazole (Note 3 - special)
    _TestCase(Organism.cAuris, Antifungal.FLU, 8.0, Interpretation.ie, 'IE'),

    // Cryptococcus - Echinocandins not applicable
    _TestCase(Organism.cryptoNeoformans, Antifungal.AND, 1.0, Interpretation.ie, 'IE'),
    _TestCase(Organism.cryptoNeoformans, Antifungal.AMB, 0.5, Interpretation.susceptible, 'S'),
  ];

  var passed = 0;
  var failed = 0;

  print('Testing interpretation logic...\n');
  print('Organism            | Drug | MIC    | Expected | Got      | Status');
  print('-' * 75);

  for (final test in testCases) {
    final result = InterpretationService.interpret(
      drug: test.drug,
      organism: test.organism,
      micValue: test.mic,
    );

    final resultLetter = _interpretationToLetter(result);
    final match = result == test.expected;

    if (match) {
      passed++;
    } else {
      failed++;
    }

    final orgName = test.organism.shortName.padRight(18);
    final drugCode = test.drug.code.padRight(4);
    final micStr = test.mic.toString().padRight(6);
    final expectedStr = test.expectedLetter.padRight(8);
    final gotStr = resultLetter.padRight(8);
    final status = match ? '✓' : '✗';

    print('$orgName | $drugCode | $micStr | $expectedStr | $gotStr | $status');
  }

  print('');
  print('=' * 60);
  print('Results: $passed passed, $failed failed');
  print('=' * 60);

  // Test breakpoint display
  print('\n\nBreakpoint Display Examples:');
  print('-' * 40);

  final displayExamples = [
    (Organism.cAlbicans, Antifungal.FLU),
    (Organism.cAlbicans, Antifungal.VOR),
    (Organism.cAlbicans, Antifungal.CAS),
    (Organism.cAuris, Antifungal.FLU),
    (Organism.cGuilliermondii, Antifungal.AMB),
  ];

  for (final (org, drug) in displayExamples) {
    final display = InterpretationService.getBreakpointDisplay(drug, org);
    print('${org.shortName} + ${drug.code}: $display');
  }
}

class _TestCase {
  final Organism organism;
  final Antifungal drug;
  final double mic;
  final Interpretation expected;
  final String expectedLetter;

  _TestCase(this.organism, this.drug, this.mic, this.expected, this.expectedLetter);
}

String _interpretationToLetter(Interpretation? interpretation) {
  switch (interpretation) {
    case Interpretation.susceptible:
      return 'S';
    case Interpretation.intermediate:
      return 'I';
    case Interpretation.resistant:
      return 'R';
    case Interpretation.ie:
      return 'IE';
    case null:
      return '-';
  }
}
