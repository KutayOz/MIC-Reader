// Test full classification pipeline
// Run with: dart run bin/test_classification.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const int kPlateRows = 8;
const int kPlateCols = 12;

// Reference classification from Python (correct results)
const Map<String, List<String>> referenceClassification = {
  'A': ['P', 'P', 'P', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U'], // AND - MIC at 0.032
  'B': ['P', 'P', 'P', 'P', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U'], // MIF - MIC at 0.064
  'C': ['P', 'P', 'P', 'P', 'P', 'U', 'U', 'U', 'U', 'U', 'U', 'U'], // CAS - MIC at 0.125
  'D': ['U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U'], // POS - MIC ≤0.004 (all purple)
  'E': ['P', 'P', 'P', 'P', 'P', 'P', 'P', 'U', 'U', 'U', 'U', 'U'], // VOR - MIC at 0.125
  'F': ['P', 'P', 'P', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U', 'U'], // ITR - MIC at 0.032
  'G': ['P', 'P', 'P', 'P', 'P', 'P', 'P', 'P', 'P', 'U', 'U', 'U'], // FLU - MIC at 64 (col 10)
  'H': ['P', 'P', 'P', 'P', 'P', 'P', 'P', 'U', 'U', 'U', 'U', 'U'], // AMB - MIC at 1 (col 8)
};

void main() async {
  final imagePath = 'test_images/WhatsApp Image 2026-02-05 at 14.15.10.jpeg';

  print('=' * 70);
  print('DART CLASSIFICATION TEST');
  print('=' * 70);

  final file = File(imagePath);
  final bytes = await file.readAsBytes();
  var image = img.decodeImage(bytes);

  if (image == null) {
    print('Error: Could not decode image');
    return;
  }

  if (image.height > image.width) {
    image = img.copyRotate(image, angle: 90);
  }

  // Plate detection
  final plateImage = detectPlateByColor(image);
  print('Plate size: ${plateImage.width}x${plateImage.height}');

  // Grid fitting
  final grid = fitGridWithBlobDetection(plateImage);
  if (grid == null) {
    print('Grid fitting failed!');
    return;
  }
  print('Grid: origin=(${grid.originX.toStringAsFixed(1)}, ${grid.originY.toStringAsFixed(1)}), '
        'step=(${grid.stepX.toStringAsFixed(1)}, ${grid.stepY.toStringAsFixed(1)})');

  // Extract well colors and classify
  print('\n${'=' * 70}');
  print('CLASSIFICATION RESULTS vs REFERENCE');
  print('=' * 70);
  print('P = Pink (growth), U = Purple (inhibition)');
  print('✓ = correct, ✗ = wrong\n');

  final sampleRadius = (math.min(grid.stepX, grid.stepY) * 0.42 * 0.45).toInt();

  var correctCount = 0;
  var wrongCount = 0;
  final wrongWells = <String>[];

  for (var row = 0; row < kPlateRows; row++) {
    final rowLabel = String.fromCharCode('A'.codeUnitAt(0) + row);
    final refRow = referenceClassification[rowLabel]!;

    stdout.write('$rowLabel: ');

    for (var col = 0; col < kPlateCols; col++) {
      final cx = (grid.originX + col * grid.stepX).toInt();
      final cy = (grid.originY + row * grid.stepY).toInt();

      // Sample color
      final colorData = sampleWellColor(plateImage, cx, cy, sampleRadius);

      // Use Python-style scoring (combines multiple factors)
      final growthScore = computeAbsoluteScore(colorData);

      // Classification thresholds from Python
      final isPink = growthScore > 0.50;

      final detected = isPink ? 'P' : 'U';
      final expected = refRow[col];
      final isCorrect = detected == expected;

      if (isCorrect) {
        correctCount++;
        stdout.write('$detected ');
      } else {
        wrongCount++;
        stdout.write('$detected!');
        wrongWells.add('$rowLabel${col + 1}(exp:$expected got:$detected sat:${colorData.saturation.toStringAsFixed(0)})');
      }
    }

    print(''); // newline
  }

  print('\n${'=' * 70}');
  print('SUMMARY: $correctCount/96 correct, $wrongCount wrong');
  print('=' * 70);

  if (wrongWells.isNotEmpty) {
    print('\nWrong wells:');
    for (final w in wrongWells) {
      print('  - $w');
    }
  }

  // Save debug image with classification overlay
  final debugImage = drawClassificationDebug(plateImage, grid, referenceClassification);
  final outputPath = 'files/debug_classification.png';
  File(outputPath).writeAsBytesSync(img.encodePng(debugImage));
  print('\nDebug image saved to: $outputPath');
}

// Include all the helper functions from the previous test...
img.Image detectPlateByColor(img.Image image) {
  final w = image.width;
  final h = image.height;

  final wellPixels = <(int, int)>[];

  for (var y = 0; y < h; y += 3) {
    for (var x = 0; x < w; x += 3) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();

      final hsv = rgbToHsv(r, g, b);
      final hue = hsv.$1;
      final sat = hsv.$2;
      final val = hsv.$3;

      if (val > 250 || val < 50) continue;

      final isPink = sat > 15 && sat < 100 && r > g * 0.9 && r > b * 0.8 && r > 130;
      final isPurple = sat > 50 && hue >= 115 && hue <= 178 && val > 60;

      if (isPink || isPurple) {
        wellPixels.add((x, y));
      }
    }
  }

  if (wellPixels.length >= 100) {
    var minX = w, maxX = 0, minY = h, maxY = 0;
    for (final (x, y) in wellPixels) {
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }

    final estimatedCellW = (maxX - minX) / 12;
    final estimatedCellH = (maxY - minY) / 8;
    final padX = (estimatedCellW * 0.3).toInt();
    final padY = (estimatedCellH * 0.3).toInt();

    minX = math.max(0, minX - padX);
    minY = math.max(0, minY - padY);
    maxX = math.min(w - 1, maxX + padX);
    maxY = math.min(h - 1, maxY + padY);

    var plate = img.copyCrop(image, x: minX, y: minY, width: maxX - minX, height: maxY - minY);

    final pw = plate.width;
    final ph = plate.height;
    final left = (pw * 0.02).toInt();
    final top = (ph * 0.03).toInt();
    final right = (pw * 0.02).toInt();
    final bottom = (ph * 0.03).toInt();

    plate = img.copyCrop(plate, x: left, y: top, width: pw - left - right, height: ph - top - bottom);

    return plate;
  }

  final marginX = (w * 0.08).toInt();
  final marginY = (h * 0.10).toInt();
  return img.copyCrop(image, x: marginX, y: marginY, width: w - 2 * marginX, height: h - 2 * marginY);
}

GridParams? fitGridWithBlobDetection(img.Image plateImage) {
  final h = plateImage.height;
  final w = plateImage.width;

  final expectedStepX = w / kPlateCols;
  final expectedStepY = h / kPlateRows;

  final wellPixels = findWellColoredPixels(plateImage);
  if (wellPixels.length < 50) return null;

  final centers = clusterIntoCenters(wellPixels, w, h, expectedStepX, expectedStepY);
  if (centers.length < 20) return null;

  var stepX = estimateStepFromPairs(centers, axis: 0, expectedStep: expectedStepX, maxOtherDist: expectedStepY * 0.4);
  var stepY = estimateStepFromPairs(centers, axis: 1, expectedStep: expectedStepY, maxOtherDist: expectedStepX * 0.4);

  stepX ??= expectedStepX;
  stepY ??= expectedStepY;

  final (bestOx, bestOy) = findBestOrigin(centers, stepX, stepY);
  return refineGridLSQ(centers, bestOx, bestOy, stepX, stepY);
}

List<(int, int)> findWellColoredPixels(img.Image image) {
  final w = image.width;
  final h = image.height;
  final pixels = <(int, int)>[];

  final marginX = (w * 0.03).toInt();
  final marginY = (h * 0.03).toInt();

  for (var y = marginY; y < h - marginY; y += 2) {
    for (var x = marginX; x < w - marginX; x += 2) {
      final pixel = image.getPixel(x, y);
      final r = pixel.r.toDouble();
      final g = pixel.g.toDouble();
      final b = pixel.b.toDouble();

      final hsv = rgbToHsv(r, g, b);
      final hue = hsv.$1;
      final sat = hsv.$2;
      final val = hsv.$3;

      if (val > 240 || val < 50) continue;
      if (sat < 25) continue;

      final isPink = sat > 25 && sat < 120 && r > g * 0.85 && r > b * 0.75 && r > 100;
      final isPurple = sat > 35 && hue >= 105 && hue <= 178 && val > 45;

      if (isPink || isPurple) {
        pixels.add((x, y));
      }
    }
  }

  return pixels;
}

List<(double, double)> clusterIntoCenters(List<(int, int)> pixels, int width, int height, double expectedStepX, double expectedStepY) {
  final binSizeX = (expectedStepX * 0.7).toInt();
  final binSizeY = (expectedStepY * 0.7).toInt();
  if (binSizeX <= 0 || binSizeY <= 0) return [];

  final binsX = (width / binSizeX).ceil();
  final bins = <int, List<(int, int)>>{};

  for (final (x, y) in pixels) {
    final binX = x ~/ binSizeX;
    final binY = y ~/ binSizeY;
    final key = binY * binsX + binX;
    bins.putIfAbsent(key, () => []).add((x, y));
  }

  final centers = <(double, double)>[];
  for (final entry in bins.entries) {
    if (entry.value.length >= 5) {
      var sumX = 0.0, sumY = 0.0;
      for (final (x, y) in entry.value) {
        sumX += x;
        sumY += y;
      }
      centers.add((sumX / entry.value.length, sumY / entry.value.length));
    }
  }

  final mergeThreshold = math.min(expectedStepX, expectedStepY) * 0.5;
  return mergeCenters(centers, mergeThreshold);
}

List<(double, double)> mergeCenters(List<(double, double)> centers, double threshold) {
  if (centers.isEmpty) return [];
  final merged = <(double, double)>[];
  final used = List<bool>.filled(centers.length, false);

  for (var i = 0; i < centers.length; i++) {
    if (used[i]) continue;
    var sumX = centers[i].$1, sumY = centers[i].$2;
    var count = 1;
    used[i] = true;

    for (var j = i + 1; j < centers.length; j++) {
      if (used[j]) continue;
      final dx = centers[i].$1 - centers[j].$1;
      final dy = centers[i].$2 - centers[j].$2;
      if (math.sqrt(dx * dx + dy * dy) < threshold) {
        sumX += centers[j].$1;
        sumY += centers[j].$2;
        count++;
        used[j] = true;
      }
    }
    merged.add((sumX / count, sumY / count));
  }
  return merged;
}

double? estimateStepFromPairs(List<(double, double)> centers, {required int axis, required double expectedStep, required double maxOtherDist}) {
  final unitDists = <double>[];
  for (var i = 0; i < centers.length; i++) {
    for (var j = i + 1; j < centers.length; j++) {
      final c1 = centers[i], c2 = centers[j];
      final c1Axis = axis == 0 ? c1.$1 : c1.$2;
      final c2Axis = axis == 0 ? c2.$1 : c2.$2;
      final c1Other = axis == 0 ? c1.$2 : c1.$1;
      final c2Other = axis == 0 ? c2.$2 : c2.$1;

      if ((c1Other - c2Other).abs() > maxOtherDist) continue;
      final axisDiff = (c1Axis - c2Axis).abs();
      if (axisDiff < expectedStep * 0.5) continue;

      final nSteps = (axisDiff / expectedStep).round();
      if (nSteps < 1 || nSteps > 12) continue;

      final unitDist = axisDiff / nSteps;
      if (unitDist > 0.7 * expectedStep && unitDist < 1.3 * expectedStep) {
        unitDists.add(unitDist);
      }
    }
  }
  if (unitDists.length < 5) return null;
  unitDists.sort();
  return unitDists[unitDists.length ~/ 2];
}

(double, double) findBestOrigin(List<(double, double)> centers, double stepX, double stepY) {
  final candidateOx = <double>{}, candidateOy = <double>{};
  final minOx = -stepX * 0.3, maxOx = stepX * 1.5;
  final minOy = -stepY * 0.3, maxOy = stepY * 1.5;

  for (final (cx, cy) in centers) {
    for (var col = 0; col < kPlateCols; col++) {
      final ox = cx - col * stepX;
      if (ox > minOx && ox < maxOx) candidateOx.add((ox * 10).roundToDouble() / 10);
    }
    for (var row = 0; row < kPlateRows; row++) {
      final oy = cy - row * stepY;
      if (oy > minOy && oy < maxOy) candidateOy.add((oy * 10).roundToDouble() / 10);
    }
  }
  candidateOx.add((stepX / 2 * 10).roundToDouble() / 10);
  candidateOy.add((stepY / 2 * 10).roundToDouble() / 10);

  var bestOx = stepX / 2, bestOy = stepY / 2, bestScore = -1;
  for (final ox in candidateOx) {
    for (final oy in candidateOy) {
      final score = scoreGrid(centers, ox, oy, stepX, stepY);
      if (score > bestScore) {
        bestScore = score;
        bestOx = ox;
        bestOy = oy;
      }
    }
  }
  return (bestOx, bestOy);
}

int scoreGrid(List<(double, double)> centers, double ox, double oy, double sx, double sy) {
  var score = 0;
  final usedSlots = <int>{};
  final threshold = math.max(sx, sy) * 0.35;

  for (final (cx, cy) in centers) {
    final col = ((cx - ox) / sx).round();
    final row = ((cy - oy) / sy).round();
    if (row >= 0 && row < kPlateRows && col >= 0 && col < kPlateCols) {
      final err = math.sqrt(math.pow(cx - ox - col * sx, 2) + math.pow(cy - oy - row * sy, 2));
      final slot = row * kPlateCols + col;
      if (err < threshold && !usedSlots.contains(slot)) {
        score++;
        usedSlots.add(slot);
      }
    }
  }
  return score;
}

GridParams refineGridLSQ(List<(double, double)> centers, double ox, double oy, double sx, double sy) {
  final threshold = math.max(sx, sy) * 0.35;
  for (var iter = 0; iter < 3; iter++) {
    final rows = <int>[], cols = <int>[], cxs = <double>[], cys = <double>[];
    for (final (cx, cy) in centers) {
      final col = ((cx - ox) / sx).round();
      final row = ((cy - oy) / sy).round();
      if (row >= 0 && row < kPlateRows && col >= 0 && col < kPlateCols) {
        final err = math.sqrt(math.pow(cx - ox - col * sx, 2) + math.pow(cy - oy - row * sy, 2));
        if (err < threshold) {
          rows.add(row);
          cols.add(col);
          cxs.add(cx);
          cys.add(cy);
        }
      }
    }
    if (cxs.length < 20) break;
    final (newOx, newSx) = leastSquares1D(cols, cxs);
    final (newOy, newSy) = leastSquares1D(rows, cys);
    if (newSx != null && newSy != null) {
      ox = newOx!;
      sx = newSx;
      oy = newOy!;
      sy = newSy;
    }
  }

  return GridParams(originX: ox, originY: oy, stepX: sx, stepY: sy);
}

(double?, double?) leastSquares1D(List<int> x, List<double> y) {
  final n = x.length;
  if (n < 2) return (null, null);
  var sumX = 0.0, sumY = 0.0, sumXX = 0.0, sumXY = 0.0;
  for (var i = 0; i < n; i++) {
    sumX += x[i];
    sumY += y[i];
    sumXX += x[i] * x[i];
    sumXY += x[i] * y[i];
  }
  final denom = n * sumXX - sumX * sumX;
  if (denom.abs() < 1e-10) return (null, null);
  final b = (n * sumXY - sumX * sumY) / denom;
  final a = (sumY - b * sumX) / n;
  return (a, b);
}

(double, double, double) rgbToHsv(double r, double g, double b) {
  final rNorm = r / 255.0, gNorm = g / 255.0, bNorm = b / 255.0;
  final maxVal = math.max(rNorm, math.max(gNorm, bNorm));
  final minVal = math.min(rNorm, math.min(gNorm, bNorm));
  final delta = maxVal - minVal;
  final v = maxVal * 255;
  final s = maxVal == 0 ? 0.0 : (delta / maxVal) * 255;
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
  h = h / 2;
  return (h, s, v);
}

class ColorData {
  final double rMean, gMean, bMean, hue, saturation, value;
  ColorData(this.rMean, this.gMean, this.bMean, this.hue, this.saturation, this.value);
}

/// Python-style absolute scoring (from color_classifier.py)
double computeAbsoluteScore(ColorData data) {
  final s = data.saturation;
  final h = data.hue;
  final rbDiff = data.rMean - data.bMean;

  var score = 0.5;

  // Saturation-based scoring (strongest signal)
  if (s < 35) {
    score += 0.35;
  } else if (s > 80) {
    score -= 0.40;
  } else if (s > 50) {
    score -= 0.20;
  } else {
    final t = (s - 35) / 15.0;
    score -= t * 0.15;
  }

  // Hue-based adjustment
  if (h >= 145 && h <= 165) {
    score -= 0.15;
    if (s > 60) score -= 0.10;
  } else if (h >= 165 || h <= 12) {
    score += 0.05;
  }

  // R-B adjustment
  if (rbDiff < 0) {
    score -= 0.10;
  } else if (rbDiff > 15) {
    score += 0.10;
  }

  // Green depression check
  if (data.gMean < data.rMean * 0.7 &&
      data.gMean < data.bMean * 0.8 &&
      s > 50) {
    score -= 0.15;
  }

  return score.clamp(0.0, 1.0);
}

ColorData sampleWellColor(img.Image image, int cx, int cy, int sampleRadius) {
  final h = image.height, w = image.width;
  var rSum = 0.0, gSum = 0.0, bSum = 0.0, hSum = 0.0, sSum = 0.0, vSum = 0.0;
  var count = 0;
  final radiusSq = sampleRadius * sampleRadius;

  for (var dy = -sampleRadius; dy <= sampleRadius; dy++) {
    for (var dx = -sampleRadius; dx <= sampleRadius; dx++) {
      if (dx * dx + dy * dy > radiusSq) continue;
      final x = cx + dx, y = cy + dy;
      if (x < 0 || x >= w || y < 0 || y >= h) continue;

      final pixel = image.getPixel(x, y);
      final r = pixel.r.toDouble(), g = pixel.g.toDouble(), b = pixel.b.toDouble();
      final hsv = rgbToHsv(r, g, b);

      if (hsv.$3 >= 245) continue; // Skip specular
      if (hsv.$2 < 15) continue;   // Skip low sat

      rSum += r;
      gSum += g;
      bSum += b;
      hSum += hsv.$1;
      sSum += hsv.$2;
      vSum += hsv.$3;
      count++;
    }
  }

  if (count < 10) {
    // Fallback without filters
    count = 0;
    rSum = gSum = bSum = hSum = sSum = vSum = 0;
    for (var dy = -sampleRadius; dy <= sampleRadius; dy++) {
      for (var dx = -sampleRadius; dx <= sampleRadius; dx++) {
        if (dx * dx + dy * dy > radiusSq) continue;
        final x = cx + dx, y = cy + dy;
        if (x < 0 || x >= w || y < 0 || y >= h) continue;

        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble(), g = pixel.g.toDouble(), b = pixel.b.toDouble();
        final hsv = rgbToHsv(r, g, b);
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

  if (count == 0) return ColorData(128, 128, 128, 0, 0, 128);
  return ColorData(rSum / count, gSum / count, bSum / count, hSum / count, sSum / count, vSum / count);
}

img.Image drawClassificationDebug(img.Image plate, GridParams grid, Map<String, List<String>> reference) {
  final debug = plate.clone();
  final sampleR = (math.min(grid.stepX, grid.stepY) * 0.42 * 0.45).toInt();

  for (var row = 0; row < kPlateRows; row++) {
    final rowLabel = String.fromCharCode('A'.codeUnitAt(0) + row);
    final refRow = reference[rowLabel]!;

    for (var col = 0; col < kPlateCols; col++) {
      final cx = (grid.originX + col * grid.stepX).toInt();
      final cy = (grid.originY + row * grid.stepY).toInt();
      final r = (math.min(grid.stepX, grid.stepY) * 0.42).toInt();

      final colorData = sampleWellColor(plate, cx, cy, sampleR);
      final isPink = colorData.saturation < 50 && (colorData.rMean - colorData.bMean) > 5;
      final detected = isPink ? 'P' : 'U';
      final expected = refRow[col];
      final isCorrect = detected == expected;

      // Green = correct, Red = wrong
      final color = isCorrect ? img.ColorRgb8(0, 255, 0) : img.ColorRgb8(255, 0, 0);

      // Draw circle
      for (var angle = 0.0; angle < 360; angle += 3) {
        final x = (cx + r * math.cos(angle * math.pi / 180)).toInt();
        final y = (cy + r * math.sin(angle * math.pi / 180)).toInt();
        if (x >= 0 && x < debug.width && y >= 0 && y < debug.height) {
          debug.setPixel(x, y, color);
          if (x + 1 < debug.width) debug.setPixel(x + 1, y, color);
        }
      }
    }
  }

  return debug;
}

class GridParams {
  final double originX, originY, stepX, stepY;
  GridParams({required this.originX, required this.originY, required this.stepX, required this.stepY});
}
