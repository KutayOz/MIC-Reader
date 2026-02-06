import '../../core/constants/drug_concentrations.dart';

/// EUCAST interpretation category
enum Interpretation {
  susceptible,   // S - Susceptible
  intermediate,  // I - Susceptible, increased exposure
  resistant,     // R - Resistant
  ie,            // IE - Insufficient Evidence
}

class MicResult {
  final Antifungal antifungal;
  final double? micValue;        // mg/L or null if undetermined
  final int? micColumn;          // 0-indexed column where MIC was found
  final Interpretation? interpretation;
  final String? note;            // e.g., "≤0.004", ">8", "Edge artifact"
  final List<double> wellScores; // Growth scores for all 12 columns

  const MicResult({
    required this.antifungal,
    this.micValue,
    this.micColumn,
    this.interpretation,
    this.note,
    this.wellScores = const [],
  });

  /// Row label (A-H)
  String get rowLabel => antifungal.row;

  /// Full drug name
  String get drugName => antifungal.fullName;

  /// Drug code (AND, MIF, etc.)
  String get drugCode => antifungal.code;

  /// Formatted MIC value for display
  String get micDisplay {
    if (note != null && note!.isNotEmpty) {
      return note!;
    }
    if (micValue == null) {
      return 'N/A';
    }
    // Format nicely: show as integer if whole number, otherwise up to 3 decimals
    if (micValue == micValue!.roundToDouble()) {
      return micValue!.toInt().toString();
    }
    return micValue!.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }

  /// Interpretation letter (S, I, R, IE)
  String get interpretationLetter {
    switch (interpretation) {
      case Interpretation.susceptible:
        return 'S';
      case Interpretation.intermediate:
        return 'I';
      case Interpretation.resistant:
        return 'R';
      case Interpretation.ie:
        return 'IE';
      case null:
        return '-';
    }
  }

  MicResult copyWith({
    Antifungal? antifungal,
    double? micValue,
    int? micColumn,
    Interpretation? interpretation,
    String? note,
    List<double>? wellScores,
  }) {
    return MicResult(
      antifungal: antifungal ?? this.antifungal,
      micValue: micValue ?? this.micValue,
      micColumn: micColumn ?? this.micColumn,
      interpretation: interpretation ?? this.interpretation,
      note: note ?? this.note,
      wellScores: wellScores ?? this.wellScores,
    );
  }

  Map<String, dynamic> toJson() => {
    'antifungal': antifungal.code,
    'micValue': micValue,
    'micColumn': micColumn,
    'interpretation': interpretation?.name,
    'note': note,
    'wellScores': wellScores,
  };

  factory MicResult.fromJson(Map<String, dynamic> json) => MicResult(
    antifungal: Antifungal.values.firstWhere((a) => a.code == json['antifungal']),
    micValue: (json['micValue'] as num?)?.toDouble(),
    micColumn: json['micColumn'] as int?,
    interpretation: json['interpretation'] != null
        ? Interpretation.values.byName(json['interpretation'] as String)
        : null,
    note: json['note'] as String?,
    wellScores: (json['wellScores'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble())
        .toList() ?? [],
  );
}
