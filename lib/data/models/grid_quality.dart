/// Grid structure detected from circle analysis
class GridStructure {
  final int rows;
  final int cols;
  final List<double> rowCenters;  // Y coordinate of each row center
  final List<double> colCenters;  // X coordinate of each column center
  final double avgStepX;
  final double avgStepY;
  final double originX;
  final double originY;

  GridStructure({
    required this.rows,
    required this.cols,
    required this.rowCenters,
    required this.colCenters,
    required this.avgStepX,
    required this.avgStepY,
    required this.originX,
    required this.originY,
  });

  /// Check if this looks like a standard 96-well plate (8x12)
  bool get isStandard96Well => rows == 8 && cols == 12;

  /// Total expected well count
  int get expectedWellCount => rows * cols;

  @override
  String toString() =>
      'GridStructure(${rows}x$cols, origin=(${originX.toStringAsFixed(1)}, ${originY.toStringAsFixed(1)}), '
      'step=(${avgStepX.toStringAsFixed(1)}, ${avgStepY.toStringAsFixed(1)}))';
}

/// Quality assessment of grid detection
class GridQuality {
  final int circleCount;
  final int expectedCount;
  final double coverageRatio;      // detected / expected (0-1)
  final double alignmentScore;     // how well circles align to grid (0-1)
  final double spacingConsistency; // how consistent spacing is (0-1)
  final double overallScore;       // weighted combination (0-1)
  final List<String> warnings;

  GridQuality({
    required this.circleCount,
    required this.expectedCount,
    required this.coverageRatio,
    required this.alignmentScore,
    required this.spacingConsistency,
    required this.overallScore,
    required this.warnings,
  });

  /// Quality is acceptable for automatic processing
  bool get isAcceptable => overallScore >= 0.7;

  /// Quality is too low, needs manual review
  bool get needsManualReview => overallScore < 0.5;

  /// Quality is marginal, results may be unreliable
  bool get isMarginal => overallScore >= 0.5 && overallScore < 0.7;

  /// Human readable quality level
  String get qualityLevel {
    if (overallScore >= 0.8) return 'Excellent';
    if (overallScore >= 0.7) return 'Good';
    if (overallScore >= 0.5) return 'Fair';
    if (overallScore >= 0.3) return 'Poor';
    return 'Very Poor';
  }

  @override
  String toString() =>
      'GridQuality($qualityLevel, score=${overallScore.toStringAsFixed(2)}, '
      'coverage=${(coverageRatio * 100).toStringAsFixed(0)}%, '
      'circles=$circleCount/$expectedCount)';
}

/// Assesses the quality of grid detection
class GridQualityAssessor {
  /// Assess quality of detected grid
  static GridQuality assessQuality({
    required List<dynamic> circles,  // List of DetectedCircle
    required GridStructure grid,
    required double imageWidth,
    required double imageHeight,
  }) {
    final warnings = <String>[];

    // 1. Coverage ratio: how many wells were detected
    final coverageRatio = circles.length / grid.expectedWellCount;
    if (coverageRatio < 0.5) {
      warnings.add('Only ${(coverageRatio * 100).toStringAsFixed(0)}% of wells detected');
    }

    // 2. Alignment score: how well circles fit the grid
    final alignmentScore = _calculateAlignmentScore(circles, grid);
    if (alignmentScore < 0.7) {
      warnings.add('Wells are poorly aligned with grid');
    }

    // 3. Spacing consistency: are step sizes uniform
    final spacingConsistency = _calculateSpacingConsistency(grid);
    if (spacingConsistency < 0.8) {
      warnings.add('Grid spacing is inconsistent');
    }

    // 4. Check for expected 96-well format
    if (!grid.isStandard96Well) {
      warnings.add('Detected ${grid.rows}x${grid.cols} grid (expected 8x12)');
    }

    // 5. Check aspect ratio
    final aspectRatio = imageWidth / imageHeight;
    if (aspectRatio < 1.2 || aspectRatio > 2.0) {
      warnings.add('Unusual image aspect ratio: ${aspectRatio.toStringAsFixed(2)}');
    }

    // Calculate overall score (weighted average)
    final overallScore = (
      coverageRatio.clamp(0.0, 1.0) * 0.40 +
      alignmentScore * 0.35 +
      spacingConsistency * 0.25
    ).clamp(0.0, 1.0);

    return GridQuality(
      circleCount: circles.length,
      expectedCount: grid.expectedWellCount,
      coverageRatio: coverageRatio.clamp(0.0, 1.0),
      alignmentScore: alignmentScore,
      spacingConsistency: spacingConsistency,
      overallScore: overallScore,
      warnings: warnings,
    );
  }

  /// Calculate how well circles align to predicted grid positions
  static double _calculateAlignmentScore(List<dynamic> circles, GridStructure grid) {
    if (circles.isEmpty) return 0.0;

    var totalError = 0.0;
    var matchedCount = 0;
    final maxError = (grid.avgStepX + grid.avgStepY) / 2 * 0.5;

    for (final circle in circles) {
      // Find nearest grid position
      final cx = circle.x as double;
      final cy = circle.y as double;

      var minDist = double.infinity;
      for (var row = 0; row < grid.rows; row++) {
        for (var col = 0; col < grid.cols; col++) {
          final predX = grid.originX + col * grid.avgStepX;
          final predY = grid.originY + row * grid.avgStepY;
          final dist = _distance(cx, cy, predX, predY);
          if (dist < minDist) {
            minDist = dist;
          }
        }
      }

      if (minDist < maxError) {
        matchedCount++;
        totalError += minDist / maxError;
      }
    }

    if (matchedCount == 0) return 0.0;

    final matchRatio = matchedCount / circles.length;
    final avgErrorRatio = totalError / matchedCount;

    return (matchRatio * 0.6 + (1.0 - avgErrorRatio) * 0.4).clamp(0.0, 1.0);
  }

  /// Calculate how consistent the grid spacing is
  static double _calculateSpacingConsistency(GridStructure grid) {
    if (grid.rowCenters.length < 2 || grid.colCenters.length < 2) {
      return 0.5; // Can't assess with fewer than 2 rows/cols
    }

    // Check row spacing consistency
    final rowSpacings = <double>[];
    for (var i = 1; i < grid.rowCenters.length; i++) {
      rowSpacings.add(grid.rowCenters[i] - grid.rowCenters[i - 1]);
    }

    // Check column spacing consistency
    final colSpacings = <double>[];
    for (var i = 1; i < grid.colCenters.length; i++) {
      colSpacings.add(grid.colCenters[i] - grid.colCenters[i - 1]);
    }

    // Calculate coefficient of variation (lower = more consistent)
    final rowCV = _coefficientOfVariation(rowSpacings);
    final colCV = _coefficientOfVariation(colSpacings);

    // Convert CV to consistency score (CV of 0 = perfect, CV of 0.5 = poor)
    final rowConsistency = (1.0 - rowCV * 2).clamp(0.0, 1.0);
    final colConsistency = (1.0 - colCV * 2).clamp(0.0, 1.0);

    return (rowConsistency + colConsistency) / 2;
  }

  static double _distance(double x1, double y1, double x2, double y2) {
    final dx = x1 - x2;
    final dy = y1 - y2;
    return (dx * dx + dy * dy);  // Squared distance for speed
  }

  static double _coefficientOfVariation(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = values.reduce((a, b) => a + b) / values.length;
    if (mean == 0) return 0.0;
    final variance = values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / values.length;
    final stdDev = variance > 0 ? variance : 0.0;
    return stdDev / mean.abs();
  }
}
