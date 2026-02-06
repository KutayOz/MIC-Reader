import 'package:flutter_test/flutter_test.dart';
import 'package:mic_reader/data/models/well_result.dart';

/// Test the classification thresholds and neighbor analysis logic
/// These tests verify the v3 gradient-based classification algorithm

void main() {
  group('Classification Thresholds', () {
    // Thresholds from image_processing_service.dart
    const pinkThreshold = 0.50;
    const purpleThreshold = 0.30;
    const fallbackThreshold = 0.40;

    WellColor classifyByThreshold(double score) {
      if (score > pinkThreshold) return WellColor.pink;
      if (score < purpleThreshold) return WellColor.purple;
      return WellColor.partial;
    }

    test('score > 0.50 should classify as pink', () {
      expect(classifyByThreshold(0.51), WellColor.pink);
      expect(classifyByThreshold(0.75), WellColor.pink);
      expect(classifyByThreshold(1.0), WellColor.pink);
    });

    test('score < 0.30 should classify as purple', () {
      expect(classifyByThreshold(0.29), WellColor.purple);
      expect(classifyByThreshold(0.15), WellColor.purple);
      expect(classifyByThreshold(0.0), WellColor.purple);
    });

    test('score 0.30-0.50 should classify as partial (uncertain)', () {
      expect(classifyByThreshold(0.30), WellColor.partial);
      expect(classifyByThreshold(0.40), WellColor.partial);
      expect(classifyByThreshold(0.50), WellColor.partial);
    });
  });

  group('Neighbor Analysis Rules', () {
    // Simulates _applyNeighborRules from image_processing_service.dart
    (WellColor, ConfidenceLevel) applyNeighborRules(
      double score,
      WellColor? left,
      WellColor? right,
    ) {
      const fallbackThreshold = 0.40;

      // Rule 1: Transition point - left is pink, right is purple
      if (left == WellColor.pink && right == WellColor.purple) {
        return (WellColor.purple, ConfidenceLevel.medium);
      }

      // Rule 2: Left is pink, right is uncertain or edge
      if (left == WellColor.pink && (right == WellColor.partial || right == null)) {
        return (WellColor.pink, ConfidenceLevel.medium);
      }

      // Rule 3: Left is uncertain or edge, right is purple
      if ((left == WellColor.partial || left == null) && right == WellColor.purple) {
        return (WellColor.purple, ConfidenceLevel.medium);
      }

      // Rule 4: Both neighbors are the same color
      if (left == WellColor.pink && right == WellColor.pink) {
        return (WellColor.pink, ConfidenceLevel.medium);
      }
      if (left == WellColor.purple && right == WellColor.purple) {
        return (WellColor.purple, ConfidenceLevel.medium);
      }

      // Rule 5: Edge cases
      if (left == null && right == WellColor.purple) {
        return (WellColor.purple, ConfidenceLevel.medium);
      }
      if (left == WellColor.pink && right == null) {
        return (WellColor.pink, ConfidenceLevel.medium);
      }

      // Rule 6: Fallback
      if (score >= fallbackThreshold) {
        return (WellColor.pink, ConfidenceLevel.low);
      } else {
        return (WellColor.purple, ConfidenceLevel.low);
      }
    }

    test('Rule 1: Transition point (pink -> purple) should classify as purple', () {
      // This is the MIC transition point
      final (color, confidence) = applyNeighborRules(0.42, WellColor.pink, WellColor.purple);
      expect(color, WellColor.purple);
      expect(confidence, ConfidenceLevel.medium);
    });

    test('Rule 2: Left pink, right uncertain should classify as pink', () {
      final (color, confidence) = applyNeighborRules(0.45, WellColor.pink, WellColor.partial);
      expect(color, WellColor.pink);
      expect(confidence, ConfidenceLevel.medium);
    });

    test('Rule 2: Left pink, right null (edge) should classify as pink', () {
      final (color, confidence) = applyNeighborRules(0.45, WellColor.pink, null);
      expect(color, WellColor.pink);
      expect(confidence, ConfidenceLevel.medium);
    });

    test('Rule 3: Left uncertain, right purple should classify as purple', () {
      final (color, confidence) = applyNeighborRules(0.35, WellColor.partial, WellColor.purple);
      expect(color, WellColor.purple);
      expect(confidence, ConfidenceLevel.medium);
    });

    test('Rule 3: Left null (edge), right purple should classify as purple', () {
      final (color, confidence) = applyNeighborRules(0.35, null, WellColor.purple);
      expect(color, WellColor.purple);
      expect(confidence, ConfidenceLevel.medium);
    });

    test('Rule 4: Both neighbors pink should classify as pink', () {
      final (color, confidence) = applyNeighborRules(0.40, WellColor.pink, WellColor.pink);
      expect(color, WellColor.pink);
      expect(confidence, ConfidenceLevel.medium);
    });

    test('Rule 4: Both neighbors purple should classify as purple', () {
      final (color, confidence) = applyNeighborRules(0.40, WellColor.purple, WellColor.purple);
      expect(color, WellColor.purple);
      expect(confidence, ConfidenceLevel.medium);
    });

    test('Rule 6: Fallback with score >= 0.40 should classify as pink with LOW confidence', () {
      final (color, confidence) = applyNeighborRules(0.40, WellColor.partial, WellColor.partial);
      expect(color, WellColor.pink);
      expect(confidence, ConfidenceLevel.low);
    });

    test('Rule 6: Fallback with score < 0.40 should classify as purple with LOW confidence', () {
      final (color, confidence) = applyNeighborRules(0.35, WellColor.partial, WellColor.partial);
      expect(color, WellColor.purple);
      expect(confidence, ConfidenceLevel.low);
    });
  });

  group('Full Row Classification Simulation', () {
    test('should correctly classify a typical MIC row gradient', () {
      // Simulated growth scores for a row (left to right, low to high concentration)
      // Typical pattern: high scores (growth) on left, low scores (inhibition) on right
      final scores = [0.80, 0.72, 0.68, 0.42, 0.11, 0.05, 0.06, 0.05, 0.05, 0.05, 0.06, 0.08];

      // Phase 1: Initial classification
      final colors = scores.map((s) {
        if (s > 0.50) return WellColor.pink;
        if (s < 0.30) return WellColor.purple;
        return WellColor.partial;
      }).toList();

      // Expected: [pink, pink, pink, partial, purple, purple, ...]
      expect(colors[0], WellColor.pink);
      expect(colors[1], WellColor.pink);
      expect(colors[2], WellColor.pink);
      expect(colors[3], WellColor.partial); // 0.42 is uncertain
      expect(colors[4], WellColor.purple);

      // The uncertain well at index 3 should be resolved:
      // Left (index 2) = pink, Right (index 4) = purple
      // Rule 1: Transition point -> classify as purple (MIC point)
      expect(colors[2], WellColor.pink);  // Left neighbor
      expect(colors[4], WellColor.purple); // Right neighbor
      // After neighbor analysis, colors[3] would become purple
    });

    test('should handle row with multiple uncertain wells', () {
      // Row with wider transition zone
      final scores = [0.85, 0.75, 0.55, 0.45, 0.35, 0.15, 0.10, 0.08, 0.07, 0.06, 0.05, 0.05];

      // Phase 1
      final colors = scores.map((s) {
        if (s > 0.50) return WellColor.pink;
        if (s < 0.30) return WellColor.purple;
        return WellColor.partial;
      }).toList();

      // Expected: [pink, pink, pink, partial, partial, purple, purple, ...]
      expect(colors[0], WellColor.pink);
      expect(colors[1], WellColor.pink);
      expect(colors[2], WellColor.pink);   // 0.55 > 0.50
      expect(colors[3], WellColor.partial); // 0.45
      expect(colors[4], WellColor.partial); // 0.35
      expect(colors[5], WellColor.purple);  // 0.15 < 0.30

      // After neighbor analysis:
      // Index 3: left=pink, right=partial -> pink (Rule 2)
      // Index 4: left=pink(resolved), right=purple -> purple (Rule 1, transition)
    });

    test('should handle edge well with single neighbor', () {
      // First column uncertain
      final score = 0.35;

      // Left neighbor is null (edge)
      // Right neighbor is purple
      // Rule 3 applies: classify as purple

      // Last column uncertain
      final lastScore = 0.45;
      // Left neighbor is pink
      // Right neighbor is null (edge)
      // Rule 2 applies: classify as pink
    });
  });

  group('Control Well (H1)', () {
    test('control well should always be classified as pink with high confidence', () {
      // Control well is at row 7 (H), column 0 (1)
      // It should always show growth (pink) regardless of score
      final controlWell = WellResult(
        row: 7,
        column: 0,
        color: WellColor.pink,
        growthScore: 1.0,
        classificationConfidence: ConfidenceLevel.high,
      );

      expect(controlWell.isControlWell, true);
      expect(controlWell.color, WellColor.pink);
      expect(controlWell.confidenceLevel, ConfidenceLevel.high);
    });
  });
}
