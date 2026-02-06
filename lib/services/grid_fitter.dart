import 'dart:math' as math;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

import '../core/constants/drug_concentrations.dart';
import '../data/models/grid_quality.dart';
import 'native_opencv.dart';

/// Grid Fitter - Dynamically finds well centers and fits a grid.
/// Uses native OpenCV HoughCircles when available, falls back to blob detection.
/// Supports both fixed 8x12 grid and adaptive grid detection.
class GridFitter {
  // Default expected grid size (standard 96-well plate)
  static const int _defaultRows = kPlateRows;  // 8
  static const int _defaultCols = kPlateCols;  // 12

  /// Detect grid structure adaptively (rows, cols, centers).
  /// Returns GridStructure with detected dimensions and quality info.
  static (GridStructure, List<DetectedCircle>)? fitGridAdaptive(img.Image plateImage) {
    final h = plateImage.height;
    final w = plateImage.width;

    // Try to detect circles
    List<DetectedCircle>? circles;
    List<(double, double)> centers;

    if (NativeOpenCV.isAvailable) {
      final rgbaBytes = _imageToRGBA(plateImage);

      // Strategy 1: Use ultra-robust detection (new enhanced pipeline)
      circles = NativeOpenCV.instance.detectWellsRobust(
        imageData: rgbaBytes,
        width: w,
        height: h,
      );

      // Strategy 2: Fall back to multi-pass detection
      if (circles == null || circles.length < 20) {
        final expectedStepX = w / _defaultCols;
        final expectedStepY = h / _defaultRows;
        final expectedCell = math.min(expectedStepX, expectedStepY);
        final expectedRadius = (expectedCell * 0.42).toInt();
        final minRadius = (expectedRadius * 0.5).toInt();
        final maxRadius = (expectedRadius * 1.5).toInt();

        circles = NativeOpenCV.instance.detectCirclesMultiPass(
          imageData: rgbaBytes,
          width: w,
          height: h,
          minRadius: minRadius,
          maxRadius: maxRadius,
        );
      }

      if (circles != null && circles.length >= 20) {
        centers = circles.map((c) => (c.x, c.y)).toList();
        print('[GridFitter] OpenCV detected ${circles.length} wells');
      } else {
        // Strategy 3: Fallback to blob detection
        circles = null;
        centers = _getBlobCenters(plateImage);
        print('[GridFitter] Blob detection fallback: ${centers.length} centers');
      }
    } else {
      centers = _getBlobCenters(plateImage);
      print('[GridFitter] No OpenCV, blob detection: ${centers.length} centers');
    }

    if (centers.length < 10) {
      print('[GridFitter] Not enough centers detected: ${centers.length}');
      return null;
    }

    // Adaptive clustering to find rows and columns
    final gridStructure = _detectGridStructure(centers, w, h);
    if (gridStructure == null) {
      print('[GridFitter] Failed to detect grid structure');
      return null;
    }

    // Create dummy circles if we used blob detection
    circles ??= centers.map((c) => DetectedCircle(x: c.$1, y: c.$2, radius: 20)).toList();

    print('[GridFitter] Adaptive detection: ${gridStructure.rows}x${gridStructure.cols} grid');
    return (gridStructure, circles);
  }

  /// Get blob centers from plate image
  static List<(double, double)> _getBlobCenters(img.Image plateImage) {
    final h = plateImage.height;
    final w = plateImage.width;
    final expectedStepX = w / _defaultCols;
    final expectedStepY = h / _defaultRows;

    final wellPixels = _findWellColoredPixels(plateImage);
    if (wellPixels.length < 50) return [];

    return _clusterIntoCenters(wellPixels, w, h, expectedStepX, expectedStepY);
  }

  /// Detect grid structure from circle centers using adaptive clustering
  static GridStructure? _detectGridStructure(
    List<(double, double)> centers,
    int imageWidth,
    int imageHeight,
  ) {
    if (centers.length < 10) return null;

    // Extract X and Y coordinates
    final xCoords = centers.map((c) => c.$1).toList()..sort();
    final yCoords = centers.map((c) => c.$2).toList()..sort();

    // Expected step sizes for 96-well plate
    final expectedStepX = imageWidth / _defaultCols;
    final expectedStepY = imageHeight / _defaultRows;

    // Cluster X coordinates to find columns
    // Use 0.5 * expected step as threshold
    final colClusters = _clusterCoordinates(xCoords, expectedStepX * 0.5);
    // Cluster Y coordinates to find rows
    final rowClusters = _clusterCoordinates(yCoords, expectedStepY * 0.5);

    if (colClusters.length < 3 || rowClusters.length < 3) {
      print('[GridFitter] Too few clusters: ${colClusters.length} cols, ${rowClusters.length} rows');
      return null;
    }

    // Calculate cluster centers
    var colCenters = colClusters.map((cluster) =>
        cluster.reduce((a, b) => a + b) / cluster.length).toList()..sort();
    var rowCenters = rowClusters.map((cluster) =>
        cluster.reduce((a, b) => a + b) / cluster.length).toList()..sort();

    // Post-process: if we have more rows/cols than expected, merge closest pairs
    // Only merge if gap is less than 60% of average step size
    final avgRowGap = rowCenters.length > 1
        ? (rowCenters.last - rowCenters.first) / (rowCenters.length - 1)
        : expectedStepY;
    final avgColGap = colCenters.length > 1
        ? (colCenters.last - colCenters.first) / (colCenters.length - 1)
        : expectedStepX;

    while (rowCenters.length > _defaultRows) {
      // Find the pair of adjacent rows with smallest gap
      var minGap = double.infinity;
      var minIdx = -1;
      for (var i = 0; i < rowCenters.length - 1; i++) {
        final gap = rowCenters[i + 1] - rowCenters[i];
        if (gap < minGap && gap < avgRowGap * 0.6) {
          minGap = gap;
          minIdx = i;
        }
      }
      // If no mergeable pair found, stop
      if (minIdx < 0) break;
      // Merge: replace pair with their average
      final newCenter = (rowCenters[minIdx] + rowCenters[minIdx + 1]) / 2;
      rowCenters = [
        ...rowCenters.sublist(0, minIdx),
        newCenter,
        ...rowCenters.sublist(minIdx + 2),
      ];
    }

    while (colCenters.length > _defaultCols) {
      var minGap = double.infinity;
      var minIdx = -1;
      for (var i = 0; i < colCenters.length - 1; i++) {
        final gap = colCenters[i + 1] - colCenters[i];
        if (gap < minGap && gap < avgColGap * 0.6) {
          minGap = gap;
          minIdx = i;
        }
      }
      if (minIdx < 0) break;
      final newCenter = (colCenters[minIdx] + colCenters[minIdx + 1]) / 2;
      colCenters = [
        ...colCenters.sublist(0, minIdx),
        newCenter,
        ...colCenters.sublist(minIdx + 2),
      ];
    }

    // Calculate average step sizes
    double avgStepX = 0;
    for (var i = 1; i < colCenters.length; i++) {
      avgStepX += colCenters[i] - colCenters[i - 1];
    }
    avgStepX /= (colCenters.length - 1);

    double avgStepY = 0;
    for (var i = 1; i < rowCenters.length; i++) {
      avgStepY += rowCenters[i] - rowCenters[i - 1];
    }
    avgStepY /= (rowCenters.length - 1);

    // Estimate origin (first well center)
    final originX = colCenters.isNotEmpty ? colCenters.first : avgStepX / 2;
    final originY = rowCenters.isNotEmpty ? rowCenters.first : avgStepY / 2;

    return GridStructure(
      rows: rowCenters.length,
      cols: colCenters.length,
      rowCenters: rowCenters,
      colCenters: colCenters,
      avgStepX: avgStepX,
      avgStepY: avgStepY,
      originX: originX,
      originY: originY,
    );
  }

  /// Cluster 1D coordinates using distance threshold
  static List<List<double>> _clusterCoordinates(List<double> coords, double threshold) {
    if (coords.isEmpty) return [];

    final clusters = <List<double>>[];
    var currentCluster = <double>[coords.first];

    for (var i = 1; i < coords.length; i++) {
      if (coords[i] - coords[i - 1] <= threshold) {
        // Same cluster
        currentCluster.add(coords[i]);
      } else {
        // New cluster
        clusters.add(currentCluster);
        currentCluster = [coords[i]];
      }
    }
    clusters.add(currentCluster);

    return clusters;
  }

  /// Convert GridStructure to GridParams for backward compatibility
  static GridParams gridStructureToParams(GridStructure structure) {
    return GridParams(
      originX: structure.originX,
      originY: structure.originY,
      stepX: structure.avgStepX,
      stepY: structure.avgStepY,
    );
  }

  /// Find well centers and fit a grid (legacy method for backward compatibility).
  /// Tries native OpenCV first, falls back to blob detection.
  static GridParams? fitGrid(img.Image plateImage) {
    // Try native OpenCV first (most accurate)
    if (NativeOpenCV.isAvailable) {
      print('[GridFitter] OpenCV is available, using native detection');
      final nativeResult = _fitGridWithOpenCV(plateImage);
      if (nativeResult != null) {
        print('[GridFitter] OpenCV detection succeeded: $nativeResult');
        return nativeResult;
      }
      print('[GridFitter] OpenCV detection failed, falling back to blob detection');
    } else {
      print('[GridFitter] OpenCV NOT available (error: ${NativeOpenCV.initializationError}), using blob detection');
    }

    // Fall back to blob detection
    final blobResult = _fitGridWithBlobDetection(plateImage);
    print('[GridFitter] Blob detection result: $blobResult');
    return blobResult;
  }

  /// Fit grid using native OpenCV HoughCircles
  static GridParams? _fitGridWithOpenCV(img.Image plateImage) {
    try {
      final h = plateImage.height;
      final w = plateImage.width;

      // Expected radius based on plate size (matching Python exactly)
      // Python: expected_cell = min(w / 12, h / 8)
      //         expected_r = expected_cell * 0.42
      //         min_r = int(expected_r * 0.5)  <- NOT 0.7!
      //         max_r = int(expected_r * 1.3)
      final expectedStepX = w / _defaultCols;
      final expectedStepY = h / _defaultRows;
      final expectedCell = math.min(expectedStepX, expectedStepY);
      final expectedRadius = (expectedCell * 0.42).toInt();
      final minRadius = (expectedRadius * 0.5).toInt();  // Python uses 0.5
      final maxRadius = (expectedRadius * 1.3).toInt();

      // Convert image to RGBA bytes
      final rgbaBytes = _imageToRGBA(plateImage);

      // Detect circles using multi-pass approach (like Python)
      final circles = NativeOpenCV.instance.detectCirclesMultiPass(
        imageData: rgbaBytes,
        width: w,
        height: h,
        minRadius: minRadius,
        maxRadius: maxRadius,
      );

      print('[GridFitter] OpenCV detected ${circles?.length ?? 0} circles (min required: 20)');

      if (circles == null || circles.length < 20) {
        return null; // Not enough circles detected
      }

      // Convert circles to centers
      final centers = circles.map((c) => (c.x, c.y)).toList();

      // Use the same grid fitting logic as blob detection
      return _fitGridFromCenters(centers, w, h, expectedStepX, expectedStepY);
    } catch (e) {
      return null;
    }
  }

  /// Convert image to RGBA byte array for native processing
  static Uint8List _imageToRGBA(img.Image image) {
    final bytes = Uint8List(image.width * image.height * 4);
    var i = 0;
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        bytes[i++] = pixel.r.toInt();
        bytes[i++] = pixel.g.toInt();
        bytes[i++] = pixel.b.toInt();
        bytes[i++] = pixel.a.toInt();
      }
    }
    return bytes;
  }

  /// Fit grid from detected centers (used by both OpenCV and blob detection)
  static GridParams? _fitGridFromCenters(
    List<(double, double)> centers,
    int w,
    int h,
    double expectedStepX,
    double expectedStepY, {
    bool applyOriginCorrection = false, // Only for blob detection
  }) {
    // Estimate step from pairwise distances
    var stepX = _estimateStepFromPairs(
      centers,
      axis: 0,
      expectedStep: expectedStepX,
      maxOtherDist: expectedStepY * 0.4,
    ) ?? expectedStepX;

    var stepY = _estimateStepFromPairs(
      centers,
      axis: 1,
      expectedStep: expectedStepY,
      maxOtherDist: expectedStepX * 0.4,
    ) ?? expectedStepY;

    // Validate step ratio
    final stepRatio = stepX / stepY;
    if (stepRatio < 0.85 || stepRatio > 1.15) {
      final avgStep = (stepX + stepY) / 2;
      stepX = avgStep;
      stepY = avgStep;
    }

    // Find best origin
    var (bestOx, bestOy) = _findBestOrigin(centers, stepX, stepY);

    // Refine with least squares
    var refined = _refineGridLSQ(centers, bestOx, bestOy, stepX, stepY);

    // Apply origin correction for blob detection
    // Blob detection finds color centroids which are biased towards pink wells
    // (less saturated, more spread out). Real well centers are ~0.3 step to the right.
    if (applyOriginCorrection) {
      final correctedOriginX = refined.originX + stepX * 0.33;
      print('[GridFitter] Applied origin correction: ${refined.originX.toStringAsFixed(1)} -> ${correctedOriginX.toStringAsFixed(1)}');
      refined = GridParams(
        originX: correctedOriginX,
        originY: refined.originY,
        stepX: refined.stepX,
        stepY: refined.stepY,
      );
    }

    return refined;
  }

  /// Find well centers using color-based blob detection and fit a grid.
  /// Returns (originX, originY, stepX, stepY) or null if fitting fails.
  static GridParams? _fitGridWithBlobDetection(img.Image plateImage) {
    final h = plateImage.height;
    final w = plateImage.width;

    // Expected step based on naive grid
    final expectedStepX = w / _defaultCols;
    final expectedStepY = h / _defaultRows;

    // Step 1: Find well-colored pixels
    final wellPixels = _findWellColoredPixels(plateImage);
    print('[GridFitter] Blob: found ${wellPixels.length} well-colored pixels');
    if (wellPixels.length < 50) {
      return null; // Not enough colored pixels
    }

    // Step 2: Cluster pixels into blob centers (well centers)
    final centers = _clusterIntoCenters(
      wellPixels,
      plateImage.width,
      plateImage.height,
      expectedStepX,
      expectedStepY,
    );

    print('[GridFitter] Blob: found ${centers.length} cluster centers');
    if (centers.length < 20) {
      return null; // Not enough well centers found
    }

    // Use common grid fitting logic (no origin correction - made results worse)
    return _fitGridFromCenters(centers, w, h, expectedStepX, expectedStepY, applyOriginCorrection: false);
  }

  /// Find pixels that are likely well colors (pink or purple).
  static List<(int, int)> _findWellColoredPixels(img.Image image) {
    final w = image.width;
    final h = image.height;
    final pixels = <(int, int)>[];

    // Calculate margin to exclude edge pixels (5% of each dimension)
    // This prevents plate frame from being detected as wells
    final marginX = (w * 0.03).toInt();
    final marginY = (h * 0.03).toInt();

    // Sample every 2nd pixel for speed, excluding edges
    for (var y = marginY; y < h - marginY; y += 2) {
      for (var x = marginX; x < w - marginX; x += 2) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toDouble();
        final g = pixel.g.toDouble();
        final b = pixel.b.toDouble();

        final hsv = _rgbToHsv(r, g, b);
        final hue = hsv.$1;
        final sat = hsv.$2;
        final val = hsv.$3;

        // Skip very bright (specular) or very dark pixels
        if (val > 240 || val < 50) continue;

        // Skip low saturation (gray/white)
        if (sat < 25) continue;

        // Pink: low-medium saturation, reddish tint
        final isPink = sat > 25 && sat < 120 && r > g * 0.85 && r > b * 0.75 && r > 100;

        // Purple: medium-high saturation, purple hue range (110-178 in 0-179 scale)
        final isPurple = sat > 35 && hue >= 105 && hue <= 178 && val > 45;

        if (isPink || isPurple) {
          pixels.add((x, y));
        }
      }
    }

    return pixels;
  }

  /// Cluster pixels into well centers using grid-based binning.
  static List<(double, double)> _clusterIntoCenters(
    List<(int, int)> pixels,
    int width,
    int height,
    double expectedStepX,
    double expectedStepY,
  ) {
    // Use a grid of bins, each bin is ~0.7 of expected step
    final binSizeX = (expectedStepX * 0.7).toInt();
    final binSizeY = (expectedStepY * 0.7).toInt();

    if (binSizeX <= 0 || binSizeY <= 0) return [];

    final binsX = (width / binSizeX).ceil();
    final binsY = (height / binSizeY).ceil();

    // Accumulate pixels in bins
    final bins = <int, List<(int, int)>>{};
    for (final (x, y) in pixels) {
      final binX = x ~/ binSizeX;
      final binY = y ~/ binSizeY;
      final key = binY * binsX + binX;
      bins.putIfAbsent(key, () => []).add((x, y));
    }

    // Find bins with significant pixel count (likely wells)
    final minPixels = 5; // Minimum pixels to consider a bin as containing a well
    final centers = <(double, double)>[];

    for (final entry in bins.entries) {
      if (entry.value.length >= minPixels) {
        // Calculate centroid
        var sumX = 0.0;
        var sumY = 0.0;
        for (final (x, y) in entry.value) {
          sumX += x;
          sumY += y;
        }
        centers.add((sumX / entry.value.length, sumY / entry.value.length));
      }
    }

    // Merge close centers (within 0.5 * expected step)
    final mergeThreshold = math.min(expectedStepX, expectedStepY) * 0.5;
    final mergedCenters = _mergeCenters(centers, mergeThreshold);

    return mergedCenters;
  }

  /// Merge centers that are too close together.
  static List<(double, double)> _mergeCenters(
    List<(double, double)> centers,
    double threshold,
  ) {
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

  /// Estimate grid step from pairwise distances between centers.
  /// axis: 0 for X, 1 for Y
  static double? _estimateStepFromPairs(
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

        // Get coordinates based on axis
        final c1Axis = axis == 0 ? c1.$1 : c1.$2;
        final c2Axis = axis == 0 ? c2.$1 : c2.$2;
        final c1Other = axis == 0 ? c1.$2 : c1.$1;
        final c2Other = axis == 0 ? c2.$2 : c2.$1;

        // Check if they're in the same row/column
        final otherDiff = (c1Other - c2Other).abs();
        if (otherDiff > maxOtherDist) continue;

        final axisDiff = (c1Axis - c2Axis).abs();
        if (axisDiff < expectedStep * 0.5) continue;

        // How many steps apart?
        final nSteps = (axisDiff / expectedStep).round();
        if (nSteps < 1 || nSteps > 12) continue;

        final unitDist = axisDiff / nSteps;
        if (unitDist > 0.7 * expectedStep && unitDist < 1.3 * expectedStep) {
          unitDists.add(unitDist);
        }
      }
    }

    if (unitDists.length < 5) return null;

    // Return median
    unitDists.sort();
    return unitDists[unitDists.length ~/ 2];
  }

  /// Find best origin using brute-force search over candidate origins.
  /// Matches Python: fit_grid_robust() origin search logic
  static (double, double) _findBestOrigin(
    List<(double, double)> centers,
    double stepX,
    double stepY,
  ) {
    final candidateOx = <double>{};
    final candidateOy = <double>{};

    // Python uses looser bounds: if -step_x * 0.3 < ox < step_x * 1.5
    final minOx = -stepX * 0.3;
    final maxOx = stepX * 1.5;
    final minOy = -stepY * 0.3;
    final maxOy = stepY * 1.5;

    // Generate candidate origins from detected centers
    for (final (cx, cy) in centers) {
      for (var colGuess = 0; colGuess < _defaultCols; colGuess++) {
        final ox = cx - colGuess * stepX;
        if (ox > minOx && ox < maxOx) {
          candidateOx.add((ox * 10).roundToDouble() / 10);
        }
      }
      for (var rowGuess = 0; rowGuess < _defaultRows; rowGuess++) {
        final oy = cy - rowGuess * stepY;
        if (oy > minOy && oy < maxOy) {
          candidateOy.add((oy * 10).roundToDouble() / 10);
        }
      }
    }

    // Add expected origin (center of first cell) as candidate
    candidateOx.add((stepX / 2 * 10).roundToDouble() / 10);
    candidateOy.add((stepY / 2 * 10).roundToDouble() / 10);

    var bestOx = stepX / 2;
    var bestOy = stepY / 2;
    var bestScore = -1;

    for (final ox in candidateOx) {
      for (final oy in candidateOy) {
        final score = _scoreGrid(centers, ox, oy, stepX, stepY);
        if (score > bestScore) {
          bestScore = score;
          bestOx = ox;
          bestOy = oy;
        }
      }
    }

    return (bestOx, bestOy);
  }

  /// Score how well centers match a grid with given parameters.
  static int _scoreGrid(
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

      if (row >= 0 && row < _defaultRows && col >= 0 && col < _defaultCols) {
        final predX = ox + col * sx;
        final predY = oy + row * sy;
        final err = math.sqrt((cx - predX) * (cx - predX) + (cy - predY) * (cy - predY));

        final slot = row * _defaultCols + col;
        if (err < threshold && !usedSlots.contains(slot)) {
          score++;
          usedSlots.add(slot);
        }
      }
    }

    return score;
  }

  /// Refine grid parameters using least squares.
  static GridParams _refineGridLSQ(
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

        if (row >= 0 && row < _defaultRows && col >= 0 && col < _defaultCols) {
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

      // Simple least squares for X: cx = ox + col * sx
      // Solve for ox and sx
      final (newOx, newSx) = _leastSquares1D(cols, cxs);
      final (newOy, newSy) = _leastSquares1D(rows, cys);

      if (newSx != null && newSy != null) {
        ox = newOx!;
        sx = newSx;
        oy = newOy!;
        sy = newSy;
      }
    }

    return GridParams(originX: ox, originY: oy, stepX: sx, stepY: sy);
  }

  /// Simple 1D least squares: y = a + b*x
  /// Returns (a, b) or (null, null) if failed.
  static (double?, double?) _leastSquares1D(List<int> x, List<double> y) {
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

  /// Convert RGB to HSV (H: 0-179, S: 0-255, V: 0-255).
  static (double, double, double) _rgbToHsv(double r, double g, double b) {
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
    h = h / 2; // Convert to 0-179 scale

    return (h, s, v);
  }
}

/// Grid parameters returned by grid fitting.
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
