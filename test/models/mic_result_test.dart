import 'package:flutter_test/flutter_test.dart';
import 'package:mic_reader/core/constants/drug_concentrations.dart';
import 'package:mic_reader/data/models/mic_result.dart';

void main() {
  group('MicResult', () {
    test('should create with required parameters', () {
      final result = MicResult(
        antifungal: Antifungal.AND,
        micValue: 0.032,
        micColumn: 4,
      );

      expect(result.antifungal, Antifungal.AND);
      expect(result.micValue, 0.032);
      expect(result.micColumn, 4);
      expect(result.interpretation, null);
      expect(result.note, null);
    });

    test('should return correct row label', () {
      expect(MicResult(antifungal: Antifungal.AND).rowLabel, 'A');
      expect(MicResult(antifungal: Antifungal.MIF).rowLabel, 'B');
      expect(MicResult(antifungal: Antifungal.FLU).rowLabel, 'G');
      expect(MicResult(antifungal: Antifungal.AMB).rowLabel, 'H');
    });

    test('should return correct drug name', () {
      expect(MicResult(antifungal: Antifungal.AND).drugName, 'Anidulafungin');
      expect(MicResult(antifungal: Antifungal.VOR).drugName, 'Voriconazole');
      expect(MicResult(antifungal: Antifungal.AMB).drugName, 'Amphotericin B');
    });

    test('should return correct drug code', () {
      expect(MicResult(antifungal: Antifungal.AND).drugCode, 'AND');
      expect(MicResult(antifungal: Antifungal.CAS).drugCode, 'CAS');
      expect(MicResult(antifungal: Antifungal.FLU).drugCode, 'FLU');
    });

    group('micDisplay', () {
      test('should show note when available', () {
        final result = MicResult(
          antifungal: Antifungal.POS,
          micValue: 0.004,
          note: '≤0.004',
        );
        expect(result.micDisplay, '≤0.004');
      });

      test('should show N/A when micValue is null and no note', () {
        final result = MicResult(antifungal: Antifungal.AND);
        expect(result.micDisplay, 'N/A');
      });

      test('should format whole numbers as integers', () {
        final result = MicResult(antifungal: Antifungal.FLU, micValue: 32.0);
        expect(result.micDisplay, '32');
      });

      test('should format decimals correctly', () {
        expect(
          MicResult(antifungal: Antifungal.AND, micValue: 0.032).micDisplay,
          '0.032',
        );
        expect(
          MicResult(antifungal: Antifungal.AND, micValue: 0.125).micDisplay,
          '0.125',
        );
        expect(
          MicResult(antifungal: Antifungal.AND, micValue: 0.5).micDisplay,
          '0.5',
        );
      });
    });

    group('interpretationLetter', () {
      test('should return S for susceptible', () {
        final result = MicResult(
          antifungal: Antifungal.AND,
          interpretation: Interpretation.susceptible,
        );
        expect(result.interpretationLetter, 'S');
      });

      test('should return I for intermediate', () {
        final result = MicResult(
          antifungal: Antifungal.AND,
          interpretation: Interpretation.intermediate,
        );
        expect(result.interpretationLetter, 'I');
      });

      test('should return R for resistant', () {
        final result = MicResult(
          antifungal: Antifungal.AND,
          interpretation: Interpretation.resistant,
        );
        expect(result.interpretationLetter, 'R');
      });

      test('should return IE for insufficient evidence', () {
        final result = MicResult(
          antifungal: Antifungal.AND,
          interpretation: Interpretation.ie,
        );
        expect(result.interpretationLetter, 'IE');
      });

      test('should return - for null interpretation', () {
        final result = MicResult(antifungal: Antifungal.AND);
        expect(result.interpretationLetter, '-');
      });
    });

    test('should serialize to JSON correctly', () {
      final result = MicResult(
        antifungal: Antifungal.VOR,
        micValue: 0.125,
        micColumn: 6,
        interpretation: Interpretation.susceptible,
        note: null,
        wellScores: [0.8, 0.7, 0.6, 0.5, 0.4, 0.2, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
      );

      final json = result.toJson();

      expect(json['antifungal'], 'VOR');
      expect(json['micValue'], 0.125);
      expect(json['micColumn'], 6);
      expect(json['interpretation'], 'susceptible');
      expect(json['wellScores'], hasLength(12));
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'antifungal': 'CAS',
        'micValue': 0.064,
        'micColumn': 5,
        'interpretation': 'resistant',
        'note': null,
        'wellScores': [0.9, 0.8, 0.7, 0.6, 0.5, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1],
      };

      final result = MicResult.fromJson(json);

      expect(result.antifungal, Antifungal.CAS);
      expect(result.micValue, 0.064);
      expect(result.micColumn, 5);
      expect(result.interpretation, Interpretation.resistant);
      expect(result.wellScores, hasLength(12));
    });

    test('copyWith should work correctly', () {
      final original = MicResult(
        antifungal: Antifungal.AND,
        micValue: 0.032,
      );

      final modified = original.copyWith(
        interpretation: Interpretation.susceptible,
        note: 'Test note',
      );

      expect(modified.antifungal, Antifungal.AND);
      expect(modified.micValue, 0.032);
      expect(modified.interpretation, Interpretation.susceptible);
      expect(modified.note, 'Test note');
    });
  });

  group('Interpretation', () {
    test('should have correct values', () {
      expect(Interpretation.values.length, 4);
      expect(Interpretation.susceptible.name, 'susceptible');
      expect(Interpretation.intermediate.name, 'intermediate');
      expect(Interpretation.resistant.name, 'resistant');
      expect(Interpretation.ie.name, 'ie');
    });
  });
}
