import 'dart:math' as math;
import 'package:image/image.dart' as img;

import '../core/constants/drug_concentrations.dart';
import '../data/models/grid_quality.dart';
import 'grid_fitter.dart';

/// Well Extractor - Extracts color data from individual wells.
/// Uses dynamic grid fitting (blob detection + least squares) like Python.
/// Falls back to naive grid if fitting fails.
class WellExtractor {
  static const int _rows = kPlateRows;
  static const int _cols = kPlateCols;

  // Python config.py parameters
  static const double _wellMaskRadiusFraction = 0.45; // Python: WELL_MASK_RADIUS_FRACTION = 0.45
  static const double _specularVThreshold = 245.0;    // Python: SPECULAR_V_THRESHOLD = 245
  static const double _minSaturation = 15.0;          // Python: MIN_SATURATION = 15

  /// Extract wells using adaptive grid structure.
  /// Uses the detected GridStructure which may have different row/col counts.
  /// Returns wells based on actual detected grid dimensions.
  static List<WellData> extractWellsAdaptive(
    img.Image plateImage,
    GridStructure gridStructure,
  ) {
    final h = plateImage.height;
    final w = plateImage.width;

    // Use adaptive grid parameters
    final rows = gridStructure.rows;
    final cols = gridStructure.cols;
    final stepX = gridStructure.avgStepX;
    final stepY = gridStructure.avgStepY;

    // Expected radius
    final expectedRadius = math.min(stepX, stepY) * 0.42;
    final sampleRadius = (expectedRadius * _wellMaskRadiusFraction).toInt();

    final wells = <WellData>[];

    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        // Use actual detected centers if available
        final cx = col < gridStructure.colCenters.length
            ? gridStructure.colCenters[col].toInt()
            : (gridStructure.originX + col * stepX).toInt();
        final cy = row < gridStructure.rowCenters.length
            ? gridStructure.rowCenters[row].toInt()
            : (gridStructure.originY + row * stepY).toInt();

        // Ensure within bounds
        final safeCx = cx.clamp(sampleRadius, w - sampleRadius - 1);
        final safeCy = cy.clamp(sampleRadius, h - sampleRadius - 1);

        // Sample color
        final colorData = _sampleWellColor(
          plateImage,
          safeCx,
          safeCy,
          sampleRadius,
        );

        wells.add(WellData(
          row: row,
          col: col,
          cx: safeCx,
          cy: safeCy,
          radius: expectedRadius.toInt(),
          rMean: colorData.rMean,
          gMean: colorData.gMean,
          bMean: colorData.bMean,
          hue: colorData.hue,
          saturation: colorData.saturation,
          value: colorData.value,
          detected: true,
        ));
      }
    }

    return wells;
  }

  /// Extract wells using dynamic grid fitting (legacy method).
  /// First tries blob-based grid fitting (like Python's Hough + grid fit).
  /// Falls back to naive grid if fitting fails.
  static List<WellData> extractWells(img.Image plateImage) {
    final h = plateImage.height;
    final w = plateImage.width;

    // Try dynamic grid fitting first
    final gridParams = GridFitter.fitGrid(plateImage);

    double originX, originY, stepX, stepY;

    if (gridParams != null) {
      // Use fitted grid parameters
      originX = gridParams.originX;
      originY = gridParams.originY;
      stepX = gridParams.stepX;
      stepY = gridParams.stepY;
    } else {
      // Fallback to naive grid
      stepX = w / _cols;
      stepY = h / _rows;
      originX = stepX / 2;
      originY = stepY / 2;
    }

    // Expected radius (Python line 119: expected_r = expected_cell * 0.42)
    final expectedRadius = math.min(stepX, stepY) * 0.42;
    // Sample radius with Python's mask fraction
    final sampleRadius = (expectedRadius * _wellMaskRadiusFraction).toInt();

    // Boundary validation: ensure wells don't sample outside plate
    final lastWellX = (originX + 11 * stepX + sampleRadius).toInt();
    if (lastWellX > w) {
      originX -= (lastWellX - w + 5);
    }
    final lastWellY = (originY + 7 * stepY + sampleRadius).toInt();
    if (lastWellY > h) {
      originY -= (lastWellY - h + 5);
    }

    final wells = <WellData>[];

    for (var row = 0; row < _rows; row++) {
      for (var col = 0; col < _cols; col++) {
        final cx = (originX + col * stepX).toInt();
        final cy = (originY + row * stepY).toInt();

        // Sample color using Python's approach
        final colorData = _sampleWellColor(
          plateImage,
          cx,
          cy,
          sampleRadius,
        );

        wells.add(WellData(
          row: row,
          col: col,
          cx: cx,
          cy: cy,
          radius: expectedRadius.toInt(),
          rMean: colorData.rMean,
          gMean: colorData.gMean,
          bMean: colorData.bMean,
          hue: colorData.hue,
          saturation: colorData.saturation,
          value: colorData.value,
          detected: gridParams != null, // True if grid was fitted
        ));
      }
    }

    return wells;
  }

  /// Sample color from a well using Python's approach
  /// Matches Python well_extractor.py lines 54-106
  static _ColorData _sampleWellColor(
    img.Image image,
    int cx,
    int cy,
    int sampleRadius,
  ) {
    final h = image.height;
    final w = image.width;

    var rSum = 0.0, gSum = 0.0, bSum = 0.0;
    var hSum = 0.0, sSum = 0.0, vSum = 0.0;
    var count = 0;

    final radiusSq = sampleRadius * sampleRadius;

    // First pass: with Python's filters (lines 75-77)
    for (var dy = -sampleRadius; dy <= sampleRadius; dy++) {
      for (var dx = -sampleRadius; dx <= sampleRadius; dx++) {
        // Check if within circle (circular mask)
        if (dx * dx + dy * dy > radiusSq) continue;

        final x = cx + dx;
        final y = cy + dy;

        // Check bounds
        if (x < 0 || x >= w || y < 0 || y >= h) continue;

        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        // Convert to HSV
        final hsv = _rgbToHsv(r, g, b);

        // Python combined_mask filters (lines 75-77):
        // (cell_hsv[:, :, 2] < SPECULAR_V_THRESHOLD) & (cell_hsv[:, :, 1] > MIN_SATURATION)
        if (hsv.$3 >= _specularVThreshold) continue; // Skip specular highlights
        if (hsv.$2 < _minSaturation) continue;       // Skip low saturation

        rSum += r;
        gSum += g;
        bSum += b;
        hSum += hsv.$1;
        sSum += hsv.$2;
        vSum += hsv.$3;
        count++;
      }
    }

    // Fallback if too few valid pixels (Python lines 82-84)
    if (count < 10) {
      // Reset and sample without filters
      count = 0;
      rSum = gSum = bSum = hSum = sSum = vSum = 0;

      for (var dy = -sampleRadius; dy <= sampleRadius; dy++) {
        for (var dx = -sampleRadius; dx <= sampleRadius; dx++) {
          if (dx * dx + dy * dy > radiusSq) continue;

          final x = cx + dx;
          final y = cy + dy;

          if (x < 0 || x >= w || y < 0 || y >= h) continue;

          final pixel = image.getPixel(x, y);
          final r = pixel.r.toDouble();
          final g = pixel.g.toDouble();
          final b = pixel.b.toDouble();
          final hsv = _rgbToHsv(r, g, b);

          rSum += r;
          gSum += g;
          bSum += b;
          hSum += hsv.$1;
          sSum += hsv.$2;
          vSum += hsv.$3;
          count++;
        }
      }
    }

    if (count == 0) {
      return _ColorData(128, 128, 128, 0, 0, 128);
    }

    // Return mean values (Python lines 87-96 use median for HSV, mean for RGB)
    // We use mean for simplicity as it works well for our use case
    return _ColorData(
      rSum / count,
      gSum / count,
      bSum / count,
      hSum / count,
      sSum / count,
      vSum / count,
    );
  }

  /// Convert RGB to HSV (H: 0-179, S: 0-255, V: 0-255)
  /// Matches OpenCV's scale used in Python
  static (double, double, double) _rgbToHsv(double r, double g, double b) {
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    final maxVal = math.max(rNorm, math.max(gNorm, bNorm));
    final minVal = math.min(rNorm, math.min(gNorm, bNorm));
    final delta = maxVal - minVal;

    // Value (0-255)
    final v = maxVal * 255;

    // Saturation (0-255)
    double s;
    if (maxVal == 0) {
      s = 0;
    } else {
      s = (delta / maxVal) * 255;
    }

    // Hue (0-179 like OpenCV)
    double h;
    if (delta == 0) {
      h = 0;
    } else if (maxVal == rNorm) {
      h = 60 * (((gNorm - bNorm) / delta) % 6);
    } else if (maxVal == gNorm) {
      h = 60 * (((bNorm - rNorm) / delta) + 2);
    } else {
      h = 60 * (((rNorm - gNorm) / delta) + 4);
    }

    if (h < 0) h += 360;
    h = h / 2; // Convert to 0-179 scale (OpenCV convention)

    return (h, s, v);
  }
}

/// Color data from well sampling
class _ColorData {
  final double rMean, gMean, bMean;
  final double hue, saturation, value;

  _ColorData(
    this.rMean,
    this.gMean,
    this.bMean,
    this.hue,
    this.saturation,
    this.value,
  );
}

/// Extracted well data
class WellData {
  final int row;
  final int col;
  final int cx;
  final int cy;
  final int radius;
  final double rMean;
  final double gMean;
  final double bMean;
  final double hue;
  final double saturation;
  final double value;
  final bool detected;

  WellData({
    required this.row,
    required this.col,
    required this.cx,
    required this.cy,
    required this.radius,
    required this.rMean,
    required this.gMean,
    required this.bMean,
    required this.hue,
    required this.saturation,
    required this.value,
    required this.detected,
  });
}
