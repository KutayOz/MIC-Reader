/// Confidence level for well classification
enum ConfidenceLevel {
  high,   // Clearly pink or purple
  medium, // Likely correct but could use verification
  low,    // Uncertain - needs manual review
}

/// Classification result for a single well
enum WellColor {
  pink,    // Growth - metabolically active cells
  purple,  // Inhibition - no growth
  partial, // Uncertain - needs manual review
}

class WellResult {
  final int row;           // 0-7 (A-H)
  final int column;        // 0-11 (1-12)
  final WellColor color;
  final double growthScore; // 0.0 (inhibition) to 1.0 (growth)
  final bool manuallyEdited;
  final ConfidenceLevel? classificationConfidence; // From classification algorithm

  // Raw color data for debugging/refinement
  final double? hue;
  final double? saturation;
  final double? value;
  final double? redMean;
  final double? greenMean;
  final double? blueMean;

  const WellResult({
    required this.row,
    required this.column,
    required this.color,
    required this.growthScore,
    this.manuallyEdited = false,
    this.classificationConfidence,
    this.hue,
    this.saturation,
    this.value,
    this.redMean,
    this.greenMean,
    this.blueMean,
  });

  /// Row label (A-H)
  String get rowLabel => String.fromCharCode('A'.codeUnitAt(0) + row);

  /// Column label (1-12)
  String get columnLabel => '${column + 1}';

  /// Well identifier (e.g., "A1", "H12")
  String get wellId => '$rowLabel$columnLabel';

  /// Is this the control well (H1)?
  bool get isControlWell => row == 7 && column == 0;

  /// Confidence level based on how decisive the growth score is
  /// Scores close to 0 or 1 = high confidence
  /// Scores close to 0.5 = low confidence
  double get confidence {
    // Distance from 0.5 (the uncertain midpoint)
    final distanceFromMiddle = (growthScore - 0.5).abs();
    // Normalize to 0-1 range (0.5 distance = 1.0 confidence)
    return distanceFromMiddle * 2;
  }

  /// Confidence level as enum for display
  /// Uses classificationConfidence if set by algorithm, otherwise falls back to score-based
  ConfidenceLevel get confidenceLevel {
    if (classificationConfidence != null) {
      return classificationConfidence!;
    }
    // Fallback: score-based confidence
    if (confidence >= 0.7) return ConfidenceLevel.high;
    if (confidence >= 0.4) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }

  /// Whether this well has low confidence and needs review
  bool get needsReview => confidenceLevel == ConfidenceLevel.low && !manuallyEdited;

  WellResult copyWith({
    int? row,
    int? column,
    WellColor? color,
    double? growthScore,
    bool? manuallyEdited,
    ConfidenceLevel? classificationConfidence,
    double? hue,
    double? saturation,
    double? value,
    double? redMean,
    double? greenMean,
    double? blueMean,
  }) {
    return WellResult(
      row: row ?? this.row,
      column: column ?? this.column,
      color: color ?? this.color,
      growthScore: growthScore ?? this.growthScore,
      manuallyEdited: manuallyEdited ?? this.manuallyEdited,
      classificationConfidence: classificationConfidence ?? this.classificationConfidence,
      hue: hue ?? this.hue,
      saturation: saturation ?? this.saturation,
      value: value ?? this.value,
      redMean: redMean ?? this.redMean,
      greenMean: greenMean ?? this.greenMean,
      blueMean: blueMean ?? this.blueMean,
    );
  }

  Map<String, dynamic> toJson() => {
    'row': row,
    'column': column,
    'color': color.name,
    'growthScore': growthScore,
    'manuallyEdited': manuallyEdited,
    'classificationConfidence': classificationConfidence?.name,
    'hue': hue,
    'saturation': saturation,
    'value': value,
    'redMean': redMean,
    'greenMean': greenMean,
    'blueMean': blueMean,
  };

  factory WellResult.fromJson(Map<String, dynamic> json) => WellResult(
    row: json['row'] as int,
    column: json['column'] as int,
    color: WellColor.values.byName(json['color'] as String),
    growthScore: (json['growthScore'] as num).toDouble(),
    manuallyEdited: json['manuallyEdited'] as bool? ?? false,
    classificationConfidence: json['classificationConfidence'] != null
        ? ConfidenceLevel.values.byName(json['classificationConfidence'] as String)
        : null,
    hue: (json['hue'] as num?)?.toDouble(),
    saturation: (json['saturation'] as num?)?.toDouble(),
    value: (json['value'] as num?)?.toDouble(),
    redMean: (json['redMean'] as num?)?.toDouble(),
    greenMean: (json['greenMean'] as num?)?.toDouble(),
    blueMean: (json['blueMean'] as num?)?.toDouble(),
  );
}
