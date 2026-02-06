// Standalone Dart test for grid fitting
// Run with: dart run bin/test_grid_fitting.dart

import 'dart:io';
import 'dart:math' as math;
import 'package:image/image.dart' as img;

const int kPlateRows = 8;
const int kPlateCols = 12;

void main() async {
  final imagePath = 'test_images/WhatsApp Image 2026-02-05 at 14.15.10.jpeg';

  print('=' * 60);
  print('DART GRID FITTING TEST');
  print('=' * 60);

  final file = File(imagePath);
  if (!file.existsSync()) {
    print('Error: Image not found at $imagePath');
    return;
  }

  final bytes = await file.readAsBytes();
  var image = img.decodeImage(bytes);

  if (image == null) {
    print('Error: Could not decode image');
    return;
  }

  print('\n[1] Original Image: ${image.width}x${image.height}');

  // Ensure landscape
  if (image.height > image.width) {
    image = img.copyRotate(image, angle: 90);
    print('    Rotated to landscape: ${image.width}x${image.height}');
  }

  // Simulate plate detection (color-based)
  print('\n[2] Plate Detection (color-based)');
  final plateImage = detectPlateByColor(image);
  print('    Plate size: ${plateImage.width}x${plateImage.height}');

  // Grid fitting with blob detection
  print('\n[3] Grid Fitting (blob detection)');
  final gridParams = fitGridWithBlobDetection(plateImage);

  if (gridParams != null) {
    print('    SUCCESS: $gridParams');

    // Save debug image
    final debugImage = drawDebugGrid(plateImage, gridParams);
    final outputPath = 'files/debug_dart_standalone.png';
    File(outputPath).writeAsBytesSync(img.encodePng(debugImage));
    print('\n[4] Debug image saved to: $outputPath');
  } else {
    print('    FAILED: Could not fit grid');
  }
}

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

  print('    Found ${wellPixels.length} well-colored pixels');

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

    print('    Color bounds: ($minX,$minY) to ($maxX,$maxY)');

    var plate = img.copyCrop(image, x: minX, y: minY, width: maxX - minX, height: maxY - minY);

    // Light crop
    final pw = plate.width;
    final ph = plate.height;
    final left = (pw * 0.02).toInt();
    final top = (ph * 0.03).toInt();
    final right = (pw * 0.02).toInt();
    final bottom = (ph * 0.03).toInt();

    plate = img.copyCrop(plate, x: left, y: top, width: pw - left - right, height: ph - top - bottom);

    return plate;
  }

  // Fallback
  final marginX = (w * 0.08).toInt();
  final marginY = (h * 0.10).toInt();
  return img.copyCrop(image, x: marginX, y: marginY, width: w - 2 * marginX, height: h - 2 * marginY);
}

GridParams? fitGridWithBlobDetection(img.Image plateImage) {
  final h = plateImage.height;
  final w = plateImage.width;

  final expectedStepX = w / kPlateCols;
  final expectedStepY = h / kPlateRows;

  // Find well-colored pixels
  final wellPixels = findWellColoredPixels(plateImage);
  print('    Well pixels: ${wellPixels.length}');

  if (wellPixels.length < 50) return null;

  // Cluster into centers
  final centers = clusterIntoCenters(wellPixels, w, h, expectedStepX, expectedStepY);
  print('    Cluster centers: ${centers.length}');

  if (centers.length < 20) return null;

  // Estimate step
  var stepX = estimateStepFromPairs(centers, axis: 0, expectedStep: expectedStepX, maxOtherDist: expectedStepY * 0.4);
  var stepY = estimateStepFromPairs(centers, axis: 1, expectedStep: expectedStepY, maxOtherDist: expectedStepX * 0.4);

  stepX ??= expectedStepX;
  stepY ??= expectedStepY;

  print('    Estimated step: ($stepX, $stepY)');

  // Find best origin
  final (bestOx, bestOy) = findBestOrigin(centers, stepX, stepY);
  print('    Best origin: ($bestOx, $bestOy)');

  // Refine with LSQ
  final refined = refineGridLSQ(centers, bestOx, bestOy, stepX, stepY);
  print('    Refined: origin=(${refined.originX.toStringAsFixed(1)}, ${refined.originY.toStringAsFixed(1)}), step=(${refined.stepX.toStringAsFixed(1)}, ${refined.stepY.toStringAsFixed(1)})');

  return refined;
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

List<(double, double)> clusterIntoCenters(
  List<(int, int)> pixels,
  int width,
  int height,
  double expectedStepX,
  double expectedStepY,
) {
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

  final minPixels = 5;
  final centers = <(double, double)>[];

  for (final entry in bins.entries) {
    if (entry.value.length >= minPixels) {
      var sumX = 0.0;
      var sumY = 0.0;
      for (final (x, y) in entry.value) {
        sumX += x;
        sumY += y;
      }
      centers.add((sumX / entry.value.length, sumY / entry.value.length));
    }
  }

  // Merge close centers
  final mergeThreshold = math.min(expectedStepX, expectedStepY) * 0.5;
  return mergeCenters(centers, mergeThreshold);
}

List<(double, double)> mergeCenters(List<(double, double)> centers, double threshold) {
  if (centers.isEmpty) return [];

  final merged = <(double, double)>[];
  final used = List<bool>.filled(centers.length, false);

  for (var i = 0; i < centers.length; i++) {
    if (used[i]) continue;

    var sumX = centers[i].$1;
    var sumY = centers[i].$2;
    var count = 1;
    used[i] = true;

    for (var j = i + 1; j < centers.length; j++) {
      if (used[j]) continue;

      final dx = centers[i].$1 - centers[j].$1;
      final dy = centers[i].$2 - centers[j].$2;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist < threshold) {
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

double? estimateStepFromPairs(
  List<(double, double)> centers, {
  required int axis,
  required double expectedStep,
  required double maxOtherDist,
}) {
  final n = centers.length;
  final unitDists = <double>[];

  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      final c1 = centers[i];
      final c2 = centers[j];

      final c1Axis = axis == 0 ? c1.$1 : c1.$2;
      final c2Axis = axis == 0 ? c2.$1 : c2.$2;
      final c1Other = axis == 0 ? c1.$2 : c1.$1;
      final c2Other = axis == 0 ? c2.$2 : c2.$1;

      final otherDiff = (c1Other - c2Other).abs();
      if (otherDiff > maxOtherDist) continue;

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

(double, double) findBestOrigin(
  List<(double, double)> centers,
  double stepX,
  double stepY,
) {
  final candidateOx = <double>{};
  final candidateOy = <double>{};

  final minOx = -stepX * 0.3;
  final maxOx = stepX * 1.5;
  final minOy = -stepY * 0.3;
  final maxOy = stepY * 1.5;

  for (final (cx, cy) in centers) {
    for (var colGuess = 0; colGuess < kPlateCols; colGuess++) {
      final ox = cx - colGuess * stepX;
      if (ox > minOx && ox < maxOx) {
        candidateOx.add((ox * 10).roundToDouble() / 10);
      }
    }
    for (var rowGuess = 0; rowGuess < kPlateRows; rowGuess++) {
      final oy = cy - rowGuess * stepY;
      if (oy > minOy && oy < maxOy) {
        candidateOy.add((oy * 10).roundToDouble() / 10);
      }
    }
  }

  candidateOx.add((stepX / 2 * 10).roundToDouble() / 10);
  candidateOy.add((stepY / 2 * 10).roundToDouble() / 10);

  var bestOx = stepX / 2;
  var bestOy = stepY / 2;
  var bestScore = -1;

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

int scoreGrid(
  List<(double, double)> centers,
  double ox,
  double oy,
  double sx,
  double sy,
) {
  var score = 0;
  final usedSlots = <int>{};
  final threshold = math.max(sx, sy) * 0.35;

  for (final (cx, cy) in centers) {
    final col = ((cx - ox) / sx).round();
    final row = ((cy - oy) / sy).round();

    if (row >= 0 && row < kPlateRows && col >= 0 && col < kPlateCols) {
      final predX = ox + col * sx;
      final predY = oy + row * sy;
      final err = math.sqrt((cx - predX) * (cx - predX) + (cy - predY) * (cy - predY));

      final slot = row * kPlateCols + col;
      if (err < threshold && !usedSlots.contains(slot)) {
        score++;
        usedSlots.add(slot);
      }
    }
  }

  return score;
}

GridParams refineGridLSQ(
  List<(double, double)> centers,
  double ox,
  double oy,
  double sx,
  double sy,
) {
  final threshold = math.max(sx, sy) * 0.35;

  for (var iteration = 0; iteration < 3; iteration++) {
    final rows = <int>[];
    final cols = <int>[];
    final cxs = <double>[];
    final cys = <double>[];

    for (final (cx, cy) in centers) {
      final col = ((cx - ox) / sx).round();
      final row = ((cy - oy) / sy).round();

      if (row >= 0 && row < kPlateRows && col >= 0 && col < kPlateCols) {
        final predX = ox + col * sx;
        final predY = oy + row * sy;
        final err = math.sqrt((cx - predX) * (cx - predX) + (cy - predY) * (cy - predY));

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

  var sumX = 0.0;
  var sumY = 0.0;
  var sumXX = 0.0;
  var sumXY = 0.0;

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
  final rNorm = r / 255.0;
  final gNorm = g / 255.0;
  final bNorm = b / 255.0;

  final maxVal = math.max(rNorm, math.max(gNorm, bNorm));
  final minVal = math.min(rNorm, math.min(gNorm, bNorm));
  final delta = maxVal - minVal;

  final v = maxVal * 255;

  double s;
  if (maxVal == 0) {
    s = 0;
  } else {
    s = (delta / maxVal) * 255;
  }

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

img.Image drawDebugGrid(img.Image plate, GridParams grid) {
  final debug = plate.clone();

  for (var row = 0; row < kPlateRows; row++) {
    for (var col = 0; col < kPlateCols; col++) {
      final cx = (grid.originX + col * grid.stepX).toInt();
      final cy = (grid.originY + row * grid.stepY).toInt();
      final r = (math.min(grid.stepX, grid.stepY) * 0.42).toInt();

      // Draw circle
      for (var angle = 0.0; angle < 360; angle += 5) {
        final x = (cx + r * math.cos(angle * math.pi / 180)).toInt();
        final y = (cy + r * math.sin(angle * math.pi / 180)).toInt();
        if (x >= 0 && x < debug.width && y >= 0 && y < debug.height) {
          debug.setPixelRgb(x, y, 0, 255, 0);
        }
      }

      // Draw center
      for (var dx = -2; dx <= 2; dx++) {
        for (var dy = -2; dy <= 2; dy++) {
          final x = cx + dx;
          final y = cy + dy;
          if (x >= 0 && x < debug.width && y >= 0 && y < debug.height) {
            debug.setPixelRgb(x, y, 255, 0, 0);
          }
        }
      }
    }
  }

  return debug;
}

class GridParams {
  final double originX;
  final double originY;
  final double stepX;
  final double stepY;

  GridParams({
    required this.originX,
    required this.originY,
    required this.stepX,
    required this.stepY,
  });

  @override
  String toString() =>
      'GridParams(origin=(${originX.toStringAsFixed(1)}, ${originY.toStringAsFixed(1)}), '
      'step=(${stepX.toStringAsFixed(1)}, ${stepY.toStringAsFixed(1)}))';
}
