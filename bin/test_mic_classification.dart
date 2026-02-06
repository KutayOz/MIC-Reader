// Test script for MIC plate classification
// Compares Dart classification with Python reference values
// Tests both legacy and adaptive grid detection
//
// Usage: dart run bin/test_mic_classification.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

// Import local services (adjust path as needed)
import '../lib/data/models/grid_quality.dart';
import '../lib/services/grid_fitter.dart';
import '../lib/services/plate_detector.dart';
import '../lib/services/well_extractor.dart';

// Reference values from Python
const pythonScores = {
  'C5': 0.358,
  'C6': 0.193,
  'G10': 0.499,
  'G11': 0.077,
  'H9': 0.319,
  'H10': 0.070,
  'D1': 0.347,
  'D2': 0.096,
};

// Expected classifications based on reference MIC values
const expectedClassification = {
  'C5': 'PINK',   // Reference MIC CAS = 0.125 (col 6)
  'C6': 'PURPLE',
  'G10': 'PINK',  // Reference MIC FLU = 64 (col 11)
  'G11': 'PURPLE',
  'H9': 'PURPLE', // Reference MIC AMB = 1 (col 9)
  'H10': 'PURPLE',
  'D1': 'PURPLE', // Reference MIC POS = ≤0.004 (col 1)
  'D2': 'PURPLE',
};

// Thresholds (matching updated Dart code)
const pinkThreshold = 0.50;
const purpleThreshold = 0.30;
const fallbackThreshold = 0.40;

void main() async {
  final imagePath = 'test_images/WhatsApp Image 2026-02-05 at 14.15.10.jpeg';

  print('=' * 60);
  print('MIC Classification Test Script');
  print('=' * 60);
  print('');

  // Load and process image
  print('[1] Loading image...');
  final file = File(imagePath);
  if (!file.existsSync()) {
    print('ERROR: Image not found at $imagePath');
    exit(1);
  }

  final bytes = await file.readAsBytes();
  var image = img.decodeImage(bytes);
  if (image == null) {
    print('ERROR: Failed to decode image');
    exit(1);
  }

  print('    Image size: ${image.width}x${image.height}');

  // Detect and crop plate
  print('[2] Detecting plate...');
  image = PlateDetector.ensureCorrectOrientation(image);
  final plateImage = PlateDetector.detectPlate(image);
  print('    Plate size: ${plateImage.width}x${plateImage.height}');

  // Extract wells using legacy method
  print('[3] Extracting wells (legacy)...');
  final wells = WellExtractor.extractWells(plateImage);
  print('    Extracted ${wells.length} wells');

  // Test adaptive grid detection
  print('');
  print('[3b] Testing adaptive grid detection...');
  final adaptiveResult = GridFitter.fitGridAdaptive(plateImage);
  if (adaptiveResult != null) {
    final gridStructure = adaptiveResult.$1;
    final circles = adaptiveResult.$2;

    print('    Detected ${gridStructure.rows}x${gridStructure.cols} grid');
    print('    Origin: (${gridStructure.originX.toStringAsFixed(1)}, ${gridStructure.originY.toStringAsFixed(1)})');
    print('    Step: (${gridStructure.avgStepX.toStringAsFixed(1)}, ${gridStructure.avgStepY.toStringAsFixed(1)})');
    print('    Circles: ${circles.length}');

    // Quality assessment
    final quality = GridQualityAssessor.assessQuality(
      circles: circles,
      grid: gridStructure,
      imageWidth: plateImage.width.toDouble(),
      imageHeight: plateImage.height.toDouble(),
    );
    print('    Quality: ${quality.qualityLevel} (score: ${quality.overallScore.toStringAsFixed(2)})');
    print('    Coverage: ${(quality.coverageRatio * 100).toStringAsFixed(0)}%');
    print('    Alignment: ${(quality.alignmentScore * 100).toStringAsFixed(0)}%');
    if (quality.warnings.isNotEmpty) {
      print('    Warnings: ${quality.warnings.join(", ")}');
    }

    // Test adaptive extraction
    final adaptiveWells = WellExtractor.extractWellsAdaptive(plateImage, gridStructure);
    print('    Adaptive wells: ${adaptiveWells.length}');
  } else {
    print('    Adaptive detection FAILED');
  }

  // Find control well
  final controlWell = wells.firstWhere((w) => w.row == 7 && w.col == 0);

  // Pre-classify for calibration
  final growthProfiles = <WellData>[];
  final inhibitionProfiles = <WellData>[];

  for (final w in wells) {
    final rbDiff = w.rMean - w.bMean;
    if (w.saturation < 35 && rbDiff > 10) {
      growthProfiles.add(w);
    }
    if (w.saturation > 80 && w.hue >= 140 && w.hue <= 165) {
      inhibitionProfiles.add(w);
    }
  }

  double growthSatMedian;
  double inhibSatMedian;

  if (growthProfiles.isNotEmpty && inhibitionProfiles.isNotEmpty) {
    growthSatMedian = _median(growthProfiles.map((w) => w.saturation).toList());
    inhibSatMedian = _median(inhibitionProfiles.map((w) => w.saturation).toList());
  } else {
    growthSatMedian = 27.0;  // From Python
    inhibSatMedian = 186.0;  // From Python
  }

  print('    Growth sat median: $growthSatMedian');
  print('    Inhib sat median: $inhibSatMedian');
  print('');

  // Test critical wells
  print('[4] Testing critical wells...');
  print('');
  print('Well  | H     S     R-B  | RelScore | AbsScore | FinalScore | Class    | Expected | Match');
  print('-' * 95);

  final criticalWells = [
    (2, 4, 'C5'),
    (2, 5, 'C6'),
    (6, 9, 'G10'),
    (6, 10, 'G11'),
    (7, 8, 'H9'),
    (7, 9, 'H10'),
    (3, 0, 'D1'),
    (3, 1, 'D2'),
  ];

  var matches = 0;
  var total = 0;

  for (final (row, col, name) in criticalWells) {
    final w = wells.firstWhere((w) => w.row == row && w.col == col);

    final relScore = _computeRelativeScore(w, controlWell, growthSatMedian, inhibSatMedian);
    final absScore = _computeAbsoluteScore(w);

    var finalScore = (0.65 * relScore) + (0.35 * absScore);
    finalScore = finalScore.clamp(0.0, 1.0);

    String classification;
    if (finalScore > pinkThreshold) {
      classification = 'PINK';
    } else if (finalScore < purpleThreshold) {
      classification = 'PURPLE';
    } else {
      // Uncertain - would need neighbor rules
      classification = finalScore >= fallbackThreshold ? 'PINK*' : 'PURPLE*';
    }

    final expected = expectedClassification[name]!;
    final match = classification.replaceAll('*', '') == expected;
    if (match) matches++;
    total++;

    final rbDiff = w.rMean - w.bMean;
    print('${name.padRight(5)} | ${w.hue.toStringAsFixed(0).padLeft(3)}  ${w.saturation.toStringAsFixed(0).padLeft(3)}   ${rbDiff.toStringAsFixed(0).padLeft(4)} | '
        '${relScore.toStringAsFixed(3).padLeft(8)} | ${absScore.toStringAsFixed(3).padLeft(8)} | '
        '${finalScore.toStringAsFixed(3).padLeft(10)} | ${classification.padRight(8)} | ${expected.padRight(8)} | ${match ? "✓" : "✗"}');
  }

  print('');
  print('Accuracy: $matches/$total (${(matches/total*100).toStringAsFixed(0)}%)');
  print('');

  // Test MIC calculation
  print('[5] Testing MIC values...');
  print('');

  final expectedMic = {
    'A': 0.032,
    'B': 0.064,
    'C': 0.125,
    'D': 0.004,  // ≤0.004
    'E': 0.125,
    'F': 0.032,
    'G': 64.0,
    'H': 1.0,
  };

  for (var rowIdx = 0; rowIdx < 8; rowIdx++) {
    final rowLabel = String.fromCharCode('A'.codeUnitAt(0) + rowIdx);
    final rowWells = wells.where((w) => w.row == rowIdx).toList()
      ..sort((a, b) => a.col.compareTo(b.col));

    // Calculate scores for each well in row
    final scores = <double>[];
    for (final w in rowWells) {
      final relScore = _computeRelativeScore(w, controlWell, growthSatMedian, inhibSatMedian);
      final absScore = _computeAbsoluteScore(w);
      var finalScore = (0.65 * relScore) + (0.35 * absScore);
      scores.add(finalScore.clamp(0.0, 1.0));
    }

    // Find first purple (simplified - without neighbor rules)
    var firstPurple = -1;
    for (var i = 0; i < scores.length; i++) {
      if (scores[i] < purpleThreshold) {
        firstPurple = i;
        break;
      }
    }

    final scoresStr = scores.map((s) => s.toStringAsFixed(2)).join(' ');
    print('Row $rowLabel: [$scoresStr] → First purple at col ${firstPurple >= 0 ? firstPurple : "NONE"}');
  }
}

double _computeRelativeScore(WellData well, WellData control, double growthSat, double inhibSat) {
  final satRange = math.max(inhibSat - growthSat, 30.0);
  final satNorm = (well.saturation - growthSat) / satRange;
  final satScore = 1.0 - satNorm.clamp(0.0, 1.0);

  final hueDist = _circularHueDistance(well.hue, control.hue);
  final hueScore = math.max(0.0, 1.0 - (hueDist / 35.0));

  final wRb = well.rMean - well.bMean;
  final cRb = control.rMean - control.bMean;
  double rbScore;
  if (cRb.abs() > 3) {
    final rbRatio = wRb / cRb;
    rbScore = rbRatio.clamp(-0.2, 1.2).clamp(0.0, 1.0);
  } else {
    rbScore = wRb > 0 ? 1.0 : 0.0;
  }

  final wGRatio = well.gMean / ((well.rMean + well.gMean + well.bMean) / 3 + 1);
  final cGRatio = control.gMean / ((control.rMean + control.gMean + control.bMean) / 3 + 1);
  final gDiff = wGRatio - cGRatio;
  final gScore = (1.0 + gDiff * 5).clamp(0.0, 1.0);

  final score = (0.40 * satScore) + (0.20 * hueScore) + (0.20 * rbScore) + (0.20 * gScore);
  return score.clamp(0.0, 1.0);
}

double _computeAbsoluteScore(WellData well) {
  final s = well.saturation;
  final h = well.hue;
  final rbDiff = well.rMean - well.bMean;

  var score = 0.5;

  // R-B Difference (most reliable)
  if (rbDiff > 40) {
    score += 0.35;
  } else if (rbDiff > 25) {
    score += 0.25;
  } else if (rbDiff > 15) {
    score += 0.15;
  } else if (rbDiff > 5) {
    score += 0.08;
  } else if (rbDiff > -5) {
    score += 0.00;
  } else if (rbDiff > -15) {
    score -= 0.12;
  } else {
    score -= 0.22;
  }

  // Saturation
  if (s < 35) {
    score += 0.20;
  } else if (s > 150) {
    score -= 0.20;
  } else if (s > 100) {
    if (rbDiff < 25) {
      score -= 0.10;
    }
  }

  // Hue
  if (h >= 145 && h <= 165) {
    if (rbDiff < 20) {
      score -= 0.08;
    }
  } else if (h >= 165 || h <= 12) {
    score += 0.05;
  }

  // Green check
  if (well.gMean < well.rMean * 0.6 && well.gMean < well.bMean * 0.7 && s > 100) {
    score -= 0.08;
  }

  return score.clamp(0.0, 1.0);
}

double _circularHueDistance(double h1, double h2) {
  final diff = (h1 - h2).abs();
  return math.min(diff, 180 - diff);
}

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[mid];
  }
  return (sorted[mid - 1] + sorted[mid]) / 2;
}
