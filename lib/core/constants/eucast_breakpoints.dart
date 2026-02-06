/// EUCAST Antifungal Clinical Breakpoint Table
/// Source: EUCAST Antifungal Clinical Breakpoint Table v10.0
///
/// Format: S ≤ value / R > value (mg/L)
/// IE = Insufficient Evidence
/// Note references explain special conditions

import '../../data/models/organism.dart';
import 'drug_concentrations.dart';

/// Breakpoint values for a drug/organism combination
class BreakpointSet {
  /// Susceptible if MIC ≤ this value (null = IE)
  final double? susceptible;

  /// Resistant if MIC > this value (null = IE)
  final double? resistant;

  /// Reference note number if applicable
  final String? note;

  const BreakpointSet({
    this.susceptible,
    this.resistant,
    this.note,
  });

  /// Returns true if insufficient evidence exists
  bool get isIE => susceptible == null || resistant == null;

  /// Returns true if no breakpoint data available (dash in table)
  bool get isNotApplicable => susceptible == null && resistant == null && note == null;
}

/// EUCAST breakpoints organized by organism and antifungal
/// Data from EUCAST Antifungal Clinical Breakpoint Table v10.0
const Map<Organism, Map<Antifungal, BreakpointSet>> kEucastBreakpoints = {
  // ============================================================
  // Candida albicans
  // ============================================================
  Organism.cAlbicans: {
    Antifungal.AMB: BreakpointSet(susceptible: 1, resistant: 1),
    Antifungal.AND: BreakpointSet(susceptible: 0.016, resistant: 0.016),
    Antifungal.CAS: BreakpointSet(note: 'Note 2'),  // IE - see caspofungin note
    Antifungal.FLU: BreakpointSet(susceptible: 2, resistant: 4),
    Antifungal.ITR: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.MIF: BreakpointSet(susceptible: 0.03, resistant: 0.03),
    Antifungal.POS: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.VOR: BreakpointSet(susceptible: 0.06, resistant: 0.25),
  },

  // ============================================================
  // Candida auris (Yellow highlighted - special attention)
  // ============================================================
  Organism.cAuris: {
    Antifungal.AMB: BreakpointSet(susceptible: 0.001, resistant: 2, note: 'Note 1'),
    Antifungal.AND: BreakpointSet(susceptible: 0.25, resistant: 0.25),
    Antifungal.CAS: BreakpointSet(),  // IE
    Antifungal.FLU: BreakpointSet(note: 'Note 3'),  // Special - see note 3
    Antifungal.ITR: BreakpointSet(),  // IE
    Antifungal.MIF: BreakpointSet(susceptible: 0.25, resistant: 0.25),
    Antifungal.POS: BreakpointSet(),  // IE
    Antifungal.VOR: BreakpointSet(),  // IE
  },

  // ============================================================
  // Candida dubliniensis
  // ============================================================
  Organism.cDubliniensis: {
    Antifungal.AMB: BreakpointSet(susceptible: 1, resistant: 1),
    Antifungal.AND: BreakpointSet(susceptible: 0.03, resistant: 0.03),
    Antifungal.CAS: BreakpointSet(),  // IE
    Antifungal.FLU: BreakpointSet(susceptible: 2, resistant: 4),
    Antifungal.ITR: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.MIF: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.POS: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.VOR: BreakpointSet(susceptible: 0.06, resistant: 0.25),
  },

  // ============================================================
  // Candida glabrata (Yellow highlighted)
  // ============================================================
  Organism.cGlabrata: {
    Antifungal.AMB: BreakpointSet(susceptible: 1, resistant: 1),
    Antifungal.AND: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.CAS: BreakpointSet(note: 'Note 2'),  // IE - see caspofungin note
    Antifungal.FLU: BreakpointSet(susceptible: 0.001, resistant: 16, note: 'Note 4'),
    Antifungal.ITR: BreakpointSet(),  // IE - higher ECOFF (Note 5)
    Antifungal.MIF: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.POS: BreakpointSet(),  // IE - higher ECOFF (Note 5)
    Antifungal.VOR: BreakpointSet(),  // IE - higher ECOFF (Note 5)
  },

  // ============================================================
  // Candida krusei
  // ============================================================
  Organism.cKrusei: {
    Antifungal.AMB: BreakpointSet(susceptible: 1, resistant: 1),
    Antifungal.AND: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.CAS: BreakpointSet(note: 'Note 2'),  // IE - see caspofungin note
    Antifungal.FLU: BreakpointSet(),  // Not applicable - intrinsically resistant
    Antifungal.ITR: BreakpointSet(),  // IE - higher ECOFF (Note 5)
    Antifungal.MIF: BreakpointSet(note: 'Note 6'),  // IE - higher MICs (Note 6)
    Antifungal.POS: BreakpointSet(),  // IE - higher ECOFF (Note 5)
    Antifungal.VOR: BreakpointSet(),  // IE - higher ECOFF (Note 5)
  },

  // ============================================================
  // Candida parapsilosis
  // ============================================================
  Organism.cParapsilosis: {
    Antifungal.AMB: BreakpointSet(susceptible: 1, resistant: 1),
    Antifungal.AND: BreakpointSet(susceptible: 4, resistant: 4),
    Antifungal.CAS: BreakpointSet(note: 'Note 2'),  // IE - see caspofungin note
    Antifungal.FLU: BreakpointSet(susceptible: 2, resistant: 4),
    Antifungal.ITR: BreakpointSet(susceptible: 0.125, resistant: 0.125),
    Antifungal.MIF: BreakpointSet(susceptible: 4, resistant: 4),
    Antifungal.POS: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.VOR: BreakpointSet(susceptible: 0.125, resistant: 0.25),
  },

  // ============================================================
  // Candida tropicalis
  // ============================================================
  Organism.cTropicalis: {
    Antifungal.AMB: BreakpointSet(susceptible: 1, resistant: 1),
    Antifungal.AND: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.CAS: BreakpointSet(note: 'Note 2'),  // IE - see caspofungin note
    Antifungal.FLU: BreakpointSet(susceptible: 2, resistant: 4),
    Antifungal.ITR: BreakpointSet(susceptible: 0.125, resistant: 0.125),
    Antifungal.MIF: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.POS: BreakpointSet(susceptible: 0.06, resistant: 0.06),
    Antifungal.VOR: BreakpointSet(susceptible: 0.125, resistant: 0.25, note: 'Note 8'),
  },

  // ============================================================
  // Candida guilliermondii - All IE
  // ============================================================
  Organism.cGuilliermondii: {
    Antifungal.AMB: BreakpointSet(),  // IE
    Antifungal.AND: BreakpointSet(),  // IE
    Antifungal.CAS: BreakpointSet(),  // IE
    Antifungal.FLU: BreakpointSet(),  // IE
    Antifungal.ITR: BreakpointSet(),  // IE
    Antifungal.MIF: BreakpointSet(),  // IE
    Antifungal.POS: BreakpointSet(),  // IE
    Antifungal.VOR: BreakpointSet(),  // IE
  },

  // ============================================================
  // Cryptococcus neoformans
  // ============================================================
  Organism.cryptoNeoformans: {
    Antifungal.AMB: BreakpointSet(susceptible: 1, resistant: 1),
    Antifungal.AND: BreakpointSet(),  // Not applicable - echinocandins ineffective
    Antifungal.CAS: BreakpointSet(),  // Not applicable - echinocandins ineffective
    Antifungal.FLU: BreakpointSet(),  // IE
    Antifungal.ITR: BreakpointSet(),  // IE
    Antifungal.MIF: BreakpointSet(),  // Not applicable - echinocandins ineffective
    Antifungal.POS: BreakpointSet(),  // IE
    Antifungal.VOR: BreakpointSet(),  // IE
  },
};

/// EUCAST Notes explaining special conditions
const Map<String, String> kEucastNotes = {
  'Note 1': 'C. auris: Susceptible category (≤0.001 mg/L) is to avoid misclassification of wild-type strains as "S".',
  'Note 2': 'Caspofungin: EUCAST breakpoints not established due to significant inter-laboratory variation. Isolates susceptible to anidulafungin/micafungin should be considered susceptible to caspofungin.',
  'Note 3': 'C. auris/Fluconazole: Most isolates exhibit MIC values >16 mg/L and harbour acquired resistance. EUCAST has insufficient data to support fluconazole therapy even when MIC is low.',
  'Note 4': 'C. glabrata: MICs should be interpreted as resistant when above 16 mg/L. Susceptible category (≤0.001 mg/L) is to avoid misclassification of wild-type strains.',
  'Note 5': 'ECOFFs for these species are higher than for C. albicans.',
  'Note 6': 'C. krusei/Micafungin: MICs are approximately three 2-fold dilutions higher than for C. albicans. Insufficient evidence to determine susceptibility.',
  'Note 7': 'Breakpoints apply for MICs determined with Tween 20 supplemented medium according to EUCAST E.Def 7.4 method.',
  'Note 8': 'Strains with MIC values above S/I breakpoint are rare. Repeat identification and susceptibility testing, send to reference laboratory if confirmed.',
};
