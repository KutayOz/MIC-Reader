import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

import '../core/constants/drug_concentrations.dart';
import '../data/models/models.dart';
import 'grid_fitter.dart';
import 'plate_detector.dart';
import 'well_extractor.dart';

/// Image processing service for MIC plate analysis.
/// v4: Uses robust plate detection and well extraction
/// Ported from Python prototype in files/
class ImageProcessingService {
  // Grid dimensions
  static const int _rows = kPlateRows;
  static const int _cols = kPlateCols;

  // Classification thresholds (matching Python)
  // Pink threshold: score > 0.50 = definitely pink
  // Purple threshold: score < 0.30 = definitely purple
  // Between 0.30-0.50: uncertain, use neighbor rules then fallback
  static const double _pinkThreshold = 0.50;
  static const double _purpleThreshold = 0.30;
  static const double _fallbackThreshold = 0.40;

  // Scoring weights
  static const double _growthSatThreshold = 35.0;
  static const double _inhibitionSatThreshold = 80.0;
  static const double _relativeWeight = 0.65;
  static const double _absoluteWeight = 0.35;

  /// Analyze a plate image and return results
  Future<PlateAnalysis> analyzeImage({
    required String imagePath,
    String? analystName,
    String? institution,
  }) async {
    // Load image
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    var image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Step 1: Ensure correct orientation (portrait -> landscape)
    // 96-well plate should be landscape (12 cols x 8 rows)
    image = PlateDetector.ensureCorrectOrientation(image);

    // Step 2: Detect and crop plate region
    final plateImage = PlateDetector.detectPlate(image);

    // Step 3: Extract wells using naive grid (Python's approach)
    final wellDataList = WellExtractor.extractWells(plateImage);

    // Step 3: Classify colors
    final wells = _classifyWells(wellDataList);

    // Step 4: Calculate MIC values
    final micResults = _calculateMic(wells);

    return PlateAnalysis(
      imagePath: imagePath,
      wells: wells,
      micResults: micResults,
      analystName: analystName,
      institution: institution,
    );
  }

  /// Analyze a plate image using adaptive grid detection
  /// Returns quality assessment alongside results for potential user review
  Future<PlateAnalysis> analyzeImageAdaptive({
    required String imagePath,
    String? analystName,
    String? institution,
  }) async {
    // Load image
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    var image = img.decodeImage(bytes);

    if (image == null) {
      throw Exception('Failed to decode image');
    }

    // Step 1: Ensure correct orientation (portrait -> landscape)
    image = PlateDetector.ensureCorrectOrientation(image);

    // Step 2: Detect and crop plate region
    final plateImage = PlateDetector.detectPlate(image);

    // Step 3: Adaptive grid detection
    final adaptiveResult = GridFitter.fitGridAdaptive(plateImage);

    List<WellData> wellDataList;
    GridQuality? gridQuality;
    GridStructure? gridStructure;

    if (adaptiveResult != null) {
      gridStructure = adaptiveResult.$1;
      final circles = adaptiveResult.$2;

      // Assess grid quality
      gridQuality = GridQualityAssessor.assessQuality(
        circles: circles,
        grid: gridStructure,
        imageWidth: plateImage.width.toDouble(),
        imageHeight: plateImage.height.toDouble(),
      );

      print('[ImageProcessingService] Grid quality: $gridQuality');

      // Use adaptive extraction if quality is acceptable
      if (gridStructure.isStandard96Well || gridQuality.isAcceptable) {
        wellDataList = WellExtractor.extractWellsAdaptive(plateImage, gridStructure);
      } else {
        // Fallback to legacy method for non-standard or low-quality grids
        print('[ImageProcessingService] Using legacy extraction (grid: ${gridStructure.rows}x${gridStructure.cols}, quality: ${gridQuality.qualityLevel})');
        wellDataList = WellExtractor.extractWells(plateImage);
      }
    } else {
      // Adaptive detection failed, use legacy method
      print('[ImageProcessingService] Adaptive detection failed, using legacy extraction');
      wellDataList = WellExtractor.extractWells(plateImage);
    }

    // Step 4: Classify colors
    final wells = _classifyWells(wellDataList);

    // Step 5: Calculate MIC values
    final micResults = _calculateMic(wells);

    return PlateAnalysis(
      imagePath: imagePath,
      wells: wells,
      micResults: micResults,
      analystName: analystName,
      institution: institution,
      gridQuality: gridQuality,
    );
  }

  /// Classify wells using hybrid scoring
  List<WellResult> _classifyWells(List<WellData> wellDataList) {
    if (wellDataList.isEmpty) return [];

    // Find control well (H1 = row 7, col 0)
    final controlWell = wellDataList.firstWhere(
      (w) => w.row == 7 && w.col == 0,
      orElse: () => wellDataList.first,
    );

    // Pre-classify obvious wells for calibration
    final growthProfiles = <WellData>[];
    final inhibitionProfiles = <WellData>[];

    for (final w in wellDataList) {
      final rbDiff = w.rMean - w.bMean;
      // Growth: low saturation, red > blue (matching Python: s < 35 and rb_diff > 10)
      if (w.saturation < 35 && rbDiff > 10) {
        growthProfiles.add(w);
      }
      // Inhibition: high saturation, purple hue range (matching Python: s > 80 and 140 <= h <= 165)
      if (w.saturation > 80 && w.hue >= 140 && w.hue <= 165) {
        inhibitionProfiles.add(w);
      }
    }

    // Calculate calibration values with better fallbacks
    // Fallback values based on typical Alamar Blue plate readings
    double growthSatMedian;
    double inhibSatMedian;

    if (growthProfiles.isNotEmpty && inhibitionProfiles.isNotEmpty) {
      // Both found - use medians
      growthSatMedian = _median(growthProfiles.map((w) => w.saturation).toList());
      inhibSatMedian = _median(inhibitionProfiles.map((w) => w.saturation).toList());
    } else if (growthProfiles.isNotEmpty) {
      // Only growth found - estimate inhibition
      growthSatMedian = _median(growthProfiles.map((w) => w.saturation).toList());
      inhibSatMedian = math.max(growthSatMedian + 50, 100.0);
    } else if (inhibitionProfiles.isNotEmpty) {
      // Only inhibition found - estimate growth
      inhibSatMedian = _median(inhibitionProfiles.map((w) => w.saturation).toList());
      growthSatMedian = math.max(inhibSatMedian - 50, 25.0);
    } else {
      // Neither found - use control well and default values
      growthSatMedian = controlWell.saturation < 80 ? controlWell.saturation : 30.0;
      inhibSatMedian = 120.0;
    }

    // Phase 1: Initial classification
    final results = <WellResult>[];

    for (final w in wellDataList) {
      final relScore = _computeRelativeScore(
          w, controlWell, growthSatMedian, inhibSatMedian);
      final absScore =
          _computeAbsoluteScore(w, growthSatMedian, inhibSatMedian);

      var growthScore = (_relativeWeight * relScore) + (_absoluteWeight * absScore);
      growthScore = growthScore.clamp(0.0, 1.0);

      WellColor color;
      ConfidenceLevel confidence;

      if (growthScore > _pinkThreshold) {
        color = WellColor.pink;
        confidence = ConfidenceLevel.high;
      } else if (growthScore < _purpleThreshold) {
        color = WellColor.purple;
        confidence = ConfidenceLevel.high;
      } else {
        color = WellColor.partial;
        confidence = ConfidenceLevel.low;
      }

      results.add(WellResult(
        row: w.row,
        column: w.col,
        color: color,
        growthScore: growthScore,
        classificationConfidence: confidence,
        hue: w.hue,
        saturation: w.saturation,
        value: w.value,
        redMean: w.rMean,
        greenMean: w.gMean,
        blueMean: w.bMean,
      ));
    }

    // Phase 2: Resolve uncertain wells using neighbor analysis
    _resolveUncertainWells(results);

    // Phase 3: Enforce monotonicity (once purple, always purple to the right)
    _enforceMonotonicity(results);

    // Force control well to pink with high confidence
    final ctrlIdx = results.indexWhere((r) => r.row == 7 && r.column == 0);
    if (ctrlIdx >= 0) {
      results[ctrlIdx] = results[ctrlIdx].copyWith(
        color: WellColor.pink,
        classificationConfidence: ConfidenceLevel.high,
      );
    }

    return results;
  }

  /// Phase 2: Resolve uncertain wells using gradient-based neighbor analysis
  void _resolveUncertainWells(List<WellResult> wells) {
    for (var row = 0; row < _rows; row++) {
      for (var col = 0; col < _cols; col++) {
        final idx = wells.indexWhere((w) => w.row == row && w.column == col);
        if (idx < 0) continue;

        final well = wells[idx];
        if (well.color != WellColor.partial) continue;

        // Get neighbors
        final leftIdx =
            wells.indexWhere((w) => w.row == row && w.column == col - 1);
        final rightIdx =
            wells.indexWhere((w) => w.row == row && w.column == col + 1);

        final leftColor = leftIdx >= 0 ? wells[leftIdx].color : null;
        final rightColor = rightIdx >= 0 ? wells[rightIdx].color : null;

        // Apply neighbor rules
        final (newColor, confidence) = _applyNeighborRules(
          well.growthScore,
          leftColor,
          rightColor,
          row,  // Pass row for AMB special handling
        );

        wells[idx] = well.copyWith(
          color: newColor,
          classificationConfidence: confidence,
        );
      }
    }
  }

  /// Phase 3: Enforce monotonicity - once purple appears, all right wells must be purple
  /// This is a biological constraint: if inhibition occurs at concentration X,
  /// it must also occur at all higher concentrations (to the right)
  void _enforceMonotonicity(List<WellResult> wells) {
    for (var row = 0; row < _rows; row++) {
      // Get wells for this row, sorted by column
      final rowWells = wells.where((w) => w.row == row).toList()
        ..sort((a, b) => a.column.compareTo(b.column));

      // Find first purple well
      var firstPurpleCol = -1;
      for (final w in rowWells) {
        if (w.color == WellColor.purple) {
          firstPurpleCol = w.column;
          break;
        }
      }

      // If no purple found, skip
      if (firstPurpleCol < 0) continue;

      // Enforce all wells to the right of first purple are also purple
      for (final w in rowWells) {
        if (w.column > firstPurpleCol && w.color != WellColor.purple) {
          final idx = wells.indexWhere(
              (well) => well.row == w.row && well.column == w.column);
          if (idx >= 0) {
            wells[idx] = wells[idx].copyWith(
              color: WellColor.purple,
              classificationConfidence: ConfidenceLevel.medium,
            );
          }
        }
      }
    }
  }

  /// Apply neighbor-based classification rules
  (WellColor, ConfidenceLevel) _applyNeighborRules(
    double score,
    WellColor? left,
    WellColor? right,
    int row,  // Row parameter for AMB special handling
  ) {
    // Rule 1: Transition point - left is pink, right is purple
    // This is typically the MIC point
    if (left == WellColor.pink && right == WellColor.purple) {
      // For AMB (row 7), always classify as purple at transition (90% inhibition threshold)
      if (row == 7) {
        return (WellColor.purple, ConfidenceLevel.medium);
      }
      // For other rows: if score is high enough, keep as pink
      // This helps wells like C5 (score 0.358) and G10 (score 0.499)
      if (score >= 0.50) {
        return (WellColor.pink, ConfidenceLevel.medium);
      }
      return (WellColor.purple, ConfidenceLevel.medium);
    }

    // Rule 2: Left is pink, right is uncertain or edge
    if (left == WellColor.pink &&
        (right == WellColor.partial || right == null)) {
      return (WellColor.pink, ConfidenceLevel.medium);
    }

    // Rule 3: Left is uncertain or edge, right is purple
    if ((left == WellColor.partial || left == null) &&
        right == WellColor.purple) {
      return (WellColor.purple, ConfidenceLevel.medium);
    }

    // Rule 4: Both neighbors same color
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
    if (score >= _fallbackThreshold) {
      return (WellColor.pink, ConfidenceLevel.low);
    } else {
      return (WellColor.purple, ConfidenceLevel.low);
    }
  }

  /// Relative score: similarity to control well
  double _computeRelativeScore(
    WellData well,
    WellData control,
    double growthSat,
    double inhibSat,
  ) {
    // Saturation distance (less weight now)
    final satRange = math.max(inhibSat - growthSat, 30.0);
    final satNorm = (well.saturation - growthSat) / satRange;
    final satScore = 1.0 - satNorm.clamp(0.0, 1.0);

    // Hue distance
    final hueDist = _circularHueDistance(well.hue, control.hue);
    final hueScore = math.max(0.0, 1.0 - (hueDist / 35.0));

    // Normalized R-B ratio (brightness-independent)
    final wMaxRB = math.max(well.rMean, well.bMean);
    final cMaxRB = math.max(control.rMean, control.bMean);
    final wNormRB = wMaxRB > 10 ? (well.rMean - well.bMean) / wMaxRB : 0.0;
    final cNormRB = cMaxRB > 10 ? (control.rMean - control.bMean) / cMaxRB : 0.0;

    // Compare normalized ratios
    double rbScore;
    if (cNormRB > 0.05) {
      // Control is pink - compare how pink the well is
      final rbRatio = wNormRB / cNormRB;
      rbScore = rbRatio.clamp(0.0, 1.2);
      rbScore = rbScore.clamp(0.0, 1.0);
    } else {
      // Control is neutral/purple (unusual) - use absolute
      rbScore = wNormRB > 0 ? 0.8 : 0.2;
    }

    // Green channel ratio
    final wGRatio = well.gMean / ((well.rMean + well.gMean + well.bMean) / 3 + 1);
    final cGRatio =
        control.gMean / ((control.rMean + control.gMean + control.bMean) / 3 + 1);
    final gDiff = wGRatio - cGRatio;
    final gScore = (1.0 + gDiff * 5).clamp(0.0, 1.0);

    // Increase weight of R-B score (most reliable)
    final score =
        (0.25 * satScore) + (0.15 * hueScore) + (0.45 * rbScore) + (0.15 * gScore);
    return score.clamp(0.0, 1.0);
  }

  /// Absolute score based on known color characteristics
  /// Key insight: NORMALIZED R-B ratio is the most reliable indicator
  /// Pink wells: R > B (red/pink tint from resorufin)
  /// Purple wells: B >= R (blue/violet from resazurin)
  double _computeAbsoluteScore(
    WellData well,
    double growthSat,
    double inhibSat,
  ) {
    final s = well.saturation;
    final h = well.hue;
    final r = well.rMean;
    final g = well.gMean;
    final b = well.bMean;

    // === PRIMARY: Normalized R-B ratio (brightness-independent) ===
    // This handles both dark pink and light purple correctly
    // Range: -1 (pure blue) to +1 (pure red)
    final maxRB = math.max(r, b);
    final normalizedRB = maxRB > 10 ? (r - b) / maxRB : 0.0;

    var score = 0.5;

    // Normalized thresholds (independent of brightness)
    if (normalizedRB > 0.25) {
      score += 0.40;  // Very strong pink (R much greater than B)
    } else if (normalizedRB > 0.15) {
      score += 0.30;  // Strong pink
    } else if (normalizedRB > 0.08) {
      score += 0.20;  // Moderate pink
    } else if (normalizedRB > 0.02) {
      score += 0.10;  // Slight pink
    } else if (normalizedRB > -0.02) {
      score += 0.00;  // Neutral (R ≈ B)
    } else if (normalizedRB > -0.08) {
      score -= 0.15;  // Slight purple
    } else if (normalizedRB > -0.15) {
      score -= 0.25;  // Moderate purple
    } else {
      score -= 0.35;  // Strong purple (B much greater than R)
    }

    // === SECONDARY: Hue angle (HSV) ===
    // Pink/Red hue: H around 0° (or 170-179 in OpenCV scale)
    // Purple hue: H around 140-160 in OpenCV scale
    if (h >= 165 || h <= 10) {
      // Pink/red hue range
      score += 0.08;
    } else if (h >= 135 && h <= 160) {
      // Purple hue range
      score -= 0.08;
    }

    // === TERTIARY: Green channel analysis ===
    // Purple wells: G is depressed relative to both R and B
    // Pink wells: G is closer to the average of R and B
    final gRatio = g / ((r + b) / 2 + 1);
    if (gRatio < 0.7 && s > 80) {
      // Low green ratio with decent saturation = likely purple
      score -= 0.05;
    } else if (gRatio > 0.85) {
      // High green ratio = more likely pink (salmon color)
      score += 0.03;
    }

    // === QUATERNARY: Saturation (weak signal) ===
    // Only use saturation as a tie-breaker
    if (s < 40) {
      score += 0.05;  // Very low sat = likely pink (faded growth)
    } else if (s > 160) {
      score -= 0.05;  // Very high sat = likely purple (strong inhibition)
    }

    return score.clamp(0.0, 1.0);
  }

  /// Recalculate MIC values after well edits
  List<MicResult> recalculateMic(List<WellResult> wells) {
    return _calculateMic(wells);
  }

  /// Calculate MIC values for each drug row
  List<MicResult> _calculateMic(List<WellResult> wells) {
    final results = <MicResult>[];

    for (var rowIdx = 0; rowIdx < _rows; rowIdx++) {
      final rowLabel = String.fromCharCode('A'.codeUnitAt(0) + rowIdx);
      final antifungal = Antifungal.fromRow(rowLabel);
      final concentrations = kConcentrations[rowLabel]!;

      // Get wells for this row, sorted by column
      final rowWells = wells.where((w) => w.row == rowIdx).toList()
        ..sort((a, b) => a.column.compareTo(b.column));

      final wellScores = rowWells.map((w) => w.growthScore).toList();

      // Start column (H row starts at col 1 due to control, others at col 0)
      final startCol = rowLabel == 'H' ? 1 : 0;

      double? micValue;
      int? micColumn;
      String? note;

      // Find MIC: first purple well
      for (var col = startCol; col < _cols; col++) {
        final well = rowWells.firstWhere(
          (w) => w.column == col,
          orElse: () => rowWells.first,
        );

        if (well.color == WellColor.purple) {
          micValue = concentrations[col];
          micColumn = col;
          break;
        }
      }

      // Handle edge cases
      if (micValue == null) {
        final allPink = rowWells
            .skip(startCol)
            .every((w) => w.color == WellColor.pink);
        if (allPink) {
          note = '>${concentrations.last}';
        } else {
          note = 'Undetermined';
        }
      } else if (micColumn == startCol) {
        note = '≤$micValue';
      }

      results.add(MicResult(
        antifungal: antifungal,
        micValue: micValue,
        micColumn: micColumn,
        note: note,
        wellScores: wellScores,
      ));
    }

    return results;
  }

  /// Circular hue distance
  double _circularHueDistance(double h1, double h2) {
    final diff = (h1 - h2).abs();
    return math.min(diff, 180 - diff);
  }

  /// Calculate median
  double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = List<double>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
