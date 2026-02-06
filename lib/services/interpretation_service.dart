/// Interpretation Service for EUCAST breakpoint analysis
///
/// Provides MIC value interpretation against EUCAST clinical breakpoints
/// to determine susceptibility (S), intermediate (I), or resistance (R).

import '../core/constants/drug_concentrations.dart';
import '../core/constants/eucast_breakpoints.dart';
import '../data/models/mic_result.dart';
import '../data/models/organism.dart';

class InterpretationService {
  /// Interpret MIC value against EUCAST breakpoints
  ///
  /// Returns:
  /// - [Interpretation.susceptible] if MIC ≤ S breakpoint
  /// - [Interpretation.intermediate] if S < MIC ≤ R breakpoint
  /// - [Interpretation.resistant] if MIC > R breakpoint
  /// - [Interpretation.ie] if no breakpoints defined (insufficient evidence)
  static Interpretation? interpret({
    required Antifungal drug,
    required Organism organism,
    required double micValue,
  }) {
    final breakpoints = kEucastBreakpoints[organism]?[drug];

    // No breakpoint data available
    if (breakpoints == null || breakpoints.isIE) {
      return Interpretation.ie;
    }

    // S ≤ susceptible threshold
    if (micValue <= breakpoints.susceptible!) {
      return Interpretation.susceptible;
    }

    // R > resistant threshold
    if (micValue > breakpoints.resistant!) {
      return Interpretation.resistant;
    }

    // Between S and R = Intermediate (Susceptible, increased exposure)
    return Interpretation.intermediate;
  }

  /// Get breakpoint values for a drug/organism combination
  static BreakpointSet? getBreakpoints(Antifungal drug, Organism organism) {
    return kEucastBreakpoints[organism]?[drug];
  }

  /// Get EUCAST note for a drug/organism combination
  static String? getNote(Antifungal drug, Organism organism) {
    final breakpoint = kEucastBreakpoints[organism]?[drug];
    if (breakpoint?.note == null) return null;
    return kEucastNotes[breakpoint!.note];
  }

  /// Get note reference (e.g., "Note 2") for a drug/organism combination
  static String? getNoteReference(Antifungal drug, Organism organism) {
    return kEucastBreakpoints[organism]?[drug]?.note;
  }

  /// Check if a drug/organism combination has EUCAST breakpoints defined
  static bool hasBreakpoints(Antifungal drug, Organism organism) {
    final breakpoints = kEucastBreakpoints[organism]?[drug];
    return breakpoints != null && !breakpoints.isIE;
  }

  /// Get formatted breakpoint string for display (e.g., "S ≤ 0.06 / R > 0.25")
  static String? getBreakpointDisplay(Antifungal drug, Organism organism) {
    final breakpoints = kEucastBreakpoints[organism]?[drug];
    if (breakpoints == null) return null;

    if (breakpoints.isIE) {
      if (breakpoints.note != null) {
        return breakpoints.note;
      }
      return 'IE';
    }

    return 'S ≤ ${breakpoints.susceptible} / R > ${breakpoints.resistant}';
  }

  /// Recalculate interpretations for a list of MIC results with a new organism
  static List<MicResult> recalculateInterpretations(
    List<MicResult> results,
    Organism organism,
  ) {
    return results.map((mic) {
      if (mic.micValue == null) {
        return mic.copyWith(interpretation: null);
      }

      final interpretation = interpret(
        drug: mic.antifungal,
        organism: organism,
        micValue: mic.micValue!,
      );

      return mic.copyWith(interpretation: interpretation);
    }).toList();
  }
}
