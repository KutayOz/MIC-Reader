import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/drug_concentrations.dart';
import '../../../data/models/models.dart';
import '../../../services/interpretation_service.dart';

/// Table displaying MIC results for all 8 antifungal drugs
class MicResultsTable extends StatelessWidget {
  final List<MicResult> results;
  final Organism? organism;

  const MicResultsTable({
    super.key,
    required this.results,
    this.organism,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header row
          Container(
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: const Row(
              children: [
                _TableCell(text: 'Row', isHeader: true, flex: 1),
                _TableCell(text: 'Drug', isHeader: true, flex: 3),
                _TableCell(text: 'MIC', isHeader: true, flex: 2),
                _TableCell(text: 'Int.', isHeader: true, flex: 1),
              ],
            ),
          ),

          // Data rows
          ...results.asMap().entries.map((entry) {
            final idx = entry.key;
            final result = entry.value;
            final isLast = idx == results.length - 1;

            return Container(
              decoration: BoxDecoration(
                color: idx.isOdd
                    ? AppColors.background
                    : AppColors.surface,
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(7))
                    : null,
              ),
              child: Row(
                children: [
                  _TableCell(text: result.rowLabel, flex: 1),
                  _TableCell(text: result.drugName, flex: 3, align: TextAlign.left),
                  _TableCell(
                    text: result.micDisplay,
                    flex: 2,
                    textStyle: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: result.micValue != null
                          ? AppColors.text
                          : AppColors.textSecondary,
                    ),
                  ),
                  _InterpretationCell(
                    interpretation: result.interpretation,
                    flex: 1,
                    drug: result.antifungal,
                    organism: organism,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TableCell extends StatelessWidget {
  final String text;
  final bool isHeader;
  final int flex;
  final TextAlign align;
  final TextStyle? textStyle;

  const _TableCell({
    required this.text,
    this.isHeader = false,
    required this.flex,
    this.align = TextAlign.center,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Text(
          text,
          textAlign: align,
          style: textStyle ??
              TextStyle(
                fontSize: isHeader ? 12 : 13,
                fontWeight: isHeader ? FontWeight.w600 : FontWeight.normal,
                color: isHeader ? AppColors.primary : AppColors.text,
              ),
        ),
      ),
    );
  }
}

class _InterpretationCell extends StatelessWidget {
  final Interpretation? interpretation;
  final int flex;
  final Antifungal? drug;
  final Organism? organism;

  const _InterpretationCell({
    required this.interpretation,
    required this.flex,
    this.drug,
    this.organism,
  });

  Color get _backgroundColor {
    switch (interpretation) {
      case Interpretation.susceptible:
        return AppColors.success;
      case Interpretation.intermediate:
        return AppColors.warning;
      case Interpretation.resistant:
        return AppColors.danger;
      case Interpretation.ie:
        return AppColors.textSecondary;
      case null:
        return Colors.transparent;
    }
  }

  String get _text {
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

  String? get _tooltipMessage {
    if (drug == null || organism == null) return null;
    final breakpointDisplay = InterpretationService.getBreakpointDisplay(drug!, organism!);
    if (breakpointDisplay == null) return null;
    return 'EUCAST: $breakpointDisplay';
  }

  @override
  Widget build(BuildContext context) {
    final badge = interpretation != null
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        : Text(
            _text,
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          );

    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: _tooltipMessage != null
              ? Tooltip(
                  message: _tooltipMessage!,
                  child: badge,
                )
              : badge,
        ),
      ),
    );
  }
}
