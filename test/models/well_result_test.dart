import 'package:flutter_test/flutter_test.dart';
import 'package:mic_reader/data/models/well_result.dart';

void main() {
  group('WellResult', () {
    test('should create with required parameters', () {
      final well = WellResult(
        row: 0,
        column: 0,
        color: WellColor.pink,
        growthScore: 0.8,
      );

      expect(well.row, 0);
      expect(well.column, 0);
      expect(well.color, WellColor.pink);
      expect(well.growthScore, 0.8);
      expect(well.manuallyEdited, false);
    });

    test('should generate correct well ID', () {
      expect(
        WellResult(row: 0, column: 0, color: WellColor.pink, growthScore: 0.8).wellId,
        'A1',
      );
      expect(
        WellResult(row: 7, column: 11, color: WellColor.purple, growthScore: 0.1).wellId,
        'H12',
      );
      expect(
        WellResult(row: 3, column: 5, color: WellColor.partial, growthScore: 0.5).wellId,
        'D6',
      );
    });

    test('should identify control well correctly', () {
      final controlWell = WellResult(
        row: 7,
        column: 0,
        color: WellColor.pink,
        growthScore: 1.0,
      );
      final regularWell = WellResult(
        row: 0,
        column: 0,
        color: WellColor.pink,
        growthScore: 0.8,
      );

      expect(controlWell.isControlWell, true);
      expect(regularWell.isControlWell, false);
    });

    test('should calculate confidence correctly', () {
      // Score 1.0 -> distance from 0.5 = 0.5 -> confidence = 1.0
      final highGrowth = WellResult(
        row: 0, column: 0, color: WellColor.pink, growthScore: 1.0,
      );
      expect(highGrowth.confidence, 1.0);

      // Score 0.0 -> distance from 0.5 = 0.5 -> confidence = 1.0
      final highInhibition = WellResult(
        row: 0, column: 0, color: WellColor.purple, growthScore: 0.0,
      );
      expect(highInhibition.confidence, 1.0);

      // Score 0.5 -> distance from 0.5 = 0.0 -> confidence = 0.0
      final uncertain = WellResult(
        row: 0, column: 0, color: WellColor.partial, growthScore: 0.5,
      );
      expect(uncertain.confidence, 0.0);
    });

    test('should use classificationConfidence when set', () {
      final well = WellResult(
        row: 0,
        column: 0,
        color: WellColor.pink,
        growthScore: 0.45, // Would be LOW based on score
        classificationConfidence: ConfidenceLevel.medium, // But set to MEDIUM
      );

      expect(well.confidenceLevel, ConfidenceLevel.medium);
    });

    test('should fall back to score-based confidence when classificationConfidence is null', () {
      final highConf = WellResult(
        row: 0, column: 0, color: WellColor.pink, growthScore: 0.9,
      );
      expect(highConf.confidenceLevel, ConfidenceLevel.high);

      final lowConf = WellResult(
        row: 0, column: 0, color: WellColor.partial, growthScore: 0.5,
      );
      expect(lowConf.confidenceLevel, ConfidenceLevel.low);
    });

    test('should identify wells needing review', () {
      final needsReview = WellResult(
        row: 0, column: 0, color: WellColor.partial, growthScore: 0.45,
        classificationConfidence: ConfidenceLevel.low,
      );
      expect(needsReview.needsReview, true);

      final edited = WellResult(
        row: 0, column: 0, color: WellColor.pink, growthScore: 0.45,
        classificationConfidence: ConfidenceLevel.low,
        manuallyEdited: true,
      );
      expect(edited.needsReview, false);

      final highConf = WellResult(
        row: 0, column: 0, color: WellColor.pink, growthScore: 0.9,
        classificationConfidence: ConfidenceLevel.high,
      );
      expect(highConf.needsReview, false);
    });

    test('should serialize to JSON correctly', () {
      final well = WellResult(
        row: 2,
        column: 5,
        color: WellColor.purple,
        growthScore: 0.15,
        manuallyEdited: true,
        classificationConfidence: ConfidenceLevel.high,
        hue: 150.0,
        saturation: 180.0,
      );

      final json = well.toJson();

      expect(json['row'], 2);
      expect(json['column'], 5);
      expect(json['color'], 'purple');
      expect(json['growthScore'], 0.15);
      expect(json['manuallyEdited'], true);
      expect(json['classificationConfidence'], 'high');
      expect(json['hue'], 150.0);
      expect(json['saturation'], 180.0);
    });

    test('should deserialize from JSON correctly', () {
      final json = {
        'row': 3,
        'column': 8,
        'color': 'pink',
        'growthScore': 0.75,
        'manuallyEdited': false,
        'classificationConfidence': 'medium',
        'hue': 170.0,
        'saturation': 30.0,
        'value': 220.0,
      };

      final well = WellResult.fromJson(json);

      expect(well.row, 3);
      expect(well.column, 8);
      expect(well.color, WellColor.pink);
      expect(well.growthScore, 0.75);
      expect(well.manuallyEdited, false);
      expect(well.classificationConfidence, ConfidenceLevel.medium);
      expect(well.hue, 170.0);
    });

    test('copyWith should work correctly', () {
      final original = WellResult(
        row: 0,
        column: 0,
        color: WellColor.partial,
        growthScore: 0.4,
      );

      final modified = original.copyWith(
        color: WellColor.pink,
        manuallyEdited: true,
        classificationConfidence: ConfidenceLevel.high,
      );

      expect(modified.row, 0);
      expect(modified.column, 0);
      expect(modified.color, WellColor.pink);
      expect(modified.growthScore, 0.4);
      expect(modified.manuallyEdited, true);
      expect(modified.classificationConfidence, ConfidenceLevel.high);
    });
  });

  group('WellColor', () {
    test('should have correct values', () {
      expect(WellColor.values.length, 3);
      expect(WellColor.pink.name, 'pink');
      expect(WellColor.purple.name, 'purple');
      expect(WellColor.partial.name, 'partial');
    });
  });

  group('ConfidenceLevel', () {
    test('should have correct values', () {
      expect(ConfidenceLevel.values.length, 3);
      expect(ConfidenceLevel.high.name, 'high');
      expect(ConfidenceLevel.medium.name, 'medium');
      expect(ConfidenceLevel.low.name, 'low');
    });
  });
}
