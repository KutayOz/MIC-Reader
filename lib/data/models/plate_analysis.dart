import 'package:uuid/uuid.dart';

import 'well_result.dart';
import 'mic_result.dart';
import 'grid_quality.dart';

class PlateAnalysis {
  final String id;
  final DateTime timestamp;
  final String imagePath;
  final String? organism;
  final List<WellResult> wells;    // 96 well results
  final List<MicResult> micResults; // 8 drug results
  final String? analystName;
  final String? institution;
  final String? notes;
  final GridQuality? gridQuality;  // Quality assessment of grid detection

  PlateAnalysis({
    String? id,
    DateTime? timestamp,
    required this.imagePath,
    this.organism,
    required this.wells,
    required this.micResults,
    this.analystName,
    this.institution,
    this.notes,
    this.gridQuality,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  /// Get well result at specific position
  WellResult? getWell(int row, int column) {
    try {
      return wells.firstWhere((w) => w.row == row && w.column == column);
    } catch (_) {
      return null;
    }
  }

  /// Get MIC result for specific drug row
  MicResult? getMicForRow(int row) {
    try {
      return micResults.firstWhere((m) => m.antifungal.row == String.fromCharCode('A'.codeUnitAt(0) + row));
    } catch (_) {
      return null;
    }
  }

  /// Count of wells showing growth
  int get growthCount => wells.where((w) => w.color == WellColor.pink).length;

  /// Count of wells showing inhibition
  int get inhibitionCount => wells.where((w) => w.color == WellColor.purple).length;

  /// Count of uncertain wells
  int get partialCount => wells.where((w) => w.color == WellColor.partial).length;

  /// Control well (H1)
  WellResult? get controlWell => getWell(7, 0);

  /// Is control well valid (showing growth)?
  bool get isControlValid {
    final ctrl = controlWell;
    return ctrl != null && ctrl.growthScore > 0.5;
  }

  /// Is grid quality acceptable for reliable results?
  bool get isGridQualityAcceptable => gridQuality?.isAcceptable ?? true;

  /// Does grid quality need manual review?
  bool get needsManualReview => gridQuality?.needsManualReview ?? false;

  /// Grid quality warnings
  List<String> get gridWarnings => gridQuality?.warnings ?? [];

  PlateAnalysis copyWith({
    String? id,
    DateTime? timestamp,
    String? imagePath,
    String? organism,
    List<WellResult>? wells,
    List<MicResult>? micResults,
    String? analystName,
    String? institution,
    String? notes,
    GridQuality? gridQuality,
  }) {
    return PlateAnalysis(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      imagePath: imagePath ?? this.imagePath,
      organism: organism ?? this.organism,
      wells: wells ?? this.wells,
      micResults: micResults ?? this.micResults,
      analystName: analystName ?? this.analystName,
      institution: institution ?? this.institution,
      notes: notes ?? this.notes,
      gridQuality: gridQuality ?? this.gridQuality,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': imagePath,
    'organism': organism,
    'wells': wells.map((w) => w.toJson()).toList(),
    'micResults': micResults.map((m) => m.toJson()).toList(),
    'analystName': analystName,
    'institution': institution,
    'notes': notes,
  };

  factory PlateAnalysis.fromJson(Map<String, dynamic> json) => PlateAnalysis(
    id: json['id'] as String,
    timestamp: DateTime.parse(json['timestamp'] as String),
    imagePath: json['imagePath'] as String,
    organism: json['organism'] as String?,
    wells: (json['wells'] as List<dynamic>)
        .map((w) => WellResult.fromJson(w as Map<String, dynamic>))
        .toList(),
    micResults: (json['micResults'] as List<dynamic>)
        .map((m) => MicResult.fromJson(m as Map<String, dynamic>))
        .toList(),
    analystName: json['analystName'] as String?,
    institution: json['institution'] as String?,
    notes: json['notes'] as String?,
  );
}
