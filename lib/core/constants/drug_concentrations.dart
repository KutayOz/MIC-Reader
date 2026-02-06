/// MIC YST Plate configuration from kit documentation (7005 MIC YST)

// Plate dimensions
const int kPlateRows = 8;
const int kPlateCols = 12;

// Row labels
const List<String> kRowLabels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

/// Antifungal agents per row
enum Antifungal {
  AND('AND', 'Anidulafungin', 'A'),
  MIF('MIF', 'Micafungin', 'B'),
  CAS('CAS', 'Caspofungin', 'C'),
  POS('POS', 'Posaconazole', 'D'),
  VOR('VOR', 'Voriconazole', 'E'),
  ITR('ITR', 'Itraconazole', 'F'),
  FLU('FLU', 'Fluconazole', 'G'),
  AMB('AMB', 'Amphotericin B', 'H');

  final String code;
  final String fullName;
  final String row;

  const Antifungal(this.code, this.fullName, this.row);

  static Antifungal fromRow(String row) {
    return Antifungal.values.firstWhere((a) => a.row == row);
  }
}

/// Concentrations (mg/L) per column for each row
/// Rows A-F: 0.004 → 8
/// Row G (FLU): 0.064 → 128
/// Row H (AMB): K(control), 0.008 → 8
const Map<String, List<double?>> kConcentrations = {
  'A': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
  'B': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
  'C': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
  'D': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
  'E': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
  'F': [0.004, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8],
  'G': [0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8, 16, 32, 64, 128],
  'H': [null, 0.008, 0.016, 0.032, 0.064, 0.125, 0.25, 0.5, 1, 2, 4, 8], // Col 1 = K (control)
};

/// Control well position (H1 = "K")
const String kControlRow = 'H';
const int kControlCol = 0;

/// MIC reading rules per antifungal type
/// AMB: 90% inhibition threshold, Others: 50% inhibition threshold
const Map<Antifungal, double> kInhibitionThresholds = {
  Antifungal.AND: 0.50,
  Antifungal.MIF: 0.50,
  Antifungal.CAS: 0.50,
  Antifungal.POS: 0.50,
  Antifungal.VOR: 0.50,
  Antifungal.ITR: 0.50,
  Antifungal.FLU: 0.50,
  Antifungal.AMB: 0.90,
};
