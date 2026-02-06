import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/drug_concentrations.dart';
import '../../../data/models/models.dart';

/// Interactive 96-well plate visualization
class PlateGridWidget extends StatelessWidget {
  final List<WellResult> wells;
  final List<MicResult> micResults;
  final void Function(WellResult well)? onWellTap;

  const PlateGridWidget({
    super.key,
    required this.wells,
    required this.micResults,
    this.onWellTap,
  });

  @override
  Widget build(BuildContext context) {
    // Build MIC column lookup
    final micColumns = <int, int>{};
    for (final mic in micResults) {
      final rowIdx = kRowLabels.indexOf(mic.rowLabel);
      if (mic.micColumn != null) {
        micColumns[rowIdx] = mic.micColumn!;
      }
    }

    return AspectRatio(
      aspectRatio: 1.4, // Slightly wider than standard plate to accommodate labels
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final totalHeight = constraints.maxHeight;

          // Reserve space for labels
          final labelWidth = totalWidth * 0.08;
          final labelHeight = totalHeight * 0.06;

          final gridWidth = totalWidth - labelWidth;
          final gridHeight = totalHeight - labelHeight;

          final cellWidth = gridWidth / kPlateCols;
          final cellHeight = gridHeight / kPlateRows;

          return Column(
            children: [
              // Column headers (1-12)
              SizedBox(
                height: labelHeight,
                child: Row(
                  children: [
                    SizedBox(width: labelWidth), // Empty corner
                    ...List.generate(kPlateCols, (col) {
                      return SizedBox(
                        width: cellWidth,
                        child: Center(
                          child: Text(
                            '${col + 1}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),

              // Grid rows
              Expanded(
                child: Row(
                  children: [
                    // Row labels (A-H with drug code)
                    SizedBox(
                      width: labelWidth,
                      child: Column(
                        children: List.generate(kPlateRows, (row) {
                          final label = kRowLabels[row];
                          final drug = Antifungal.fromRow(label).code;
                          return SizedBox(
                            height: cellHeight,
                            child: Center(
                              child: Text(
                                '$label\n$drug',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Well grid
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Column(
                          children: List.generate(kPlateRows, (row) {
                            return Expanded(
                              child: Row(
                                children: List.generate(kPlateCols, (col) {
                                  final well = wells.firstWhere(
                                    (w) => w.row == row && w.column == col,
                                    orElse: () => WellResult(
                                      row: row,
                                      column: col,
                                      color: WellColor.partial,
                                      growthScore: 0.5,
                                    ),
                                  );

                                  final isMicWell = micColumns[row] == col;

                                  return Expanded(
                                    child: _WellCell(
                                      well: well,
                                      isMicWell: isMicWell,
                                      onTap: onWellTap != null
                                          ? () => onWellTap!(well)
                                          : null,
                                    ),
                                  );
                                }),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WellCell extends StatelessWidget {
  final WellResult well;
  final bool isMicWell;
  final VoidCallback? onTap;

  const _WellCell({
    required this.well,
    required this.isMicWell,
    this.onTap,
  });

  Color get _wellColor {
    switch (well.color) {
      case WellColor.pink:
        return AppColors.growth;
      case WellColor.purple:
        return AppColors.inhibition;
      case WellColor.partial:
        return AppColors.warning;
    }
  }

  /// Border color based on confidence and MIC status
  Color get _borderColor {
    if (isMicWell) return AppColors.primary;
    if (well.needsReview) return AppColors.warning;
    if (well.manuallyEdited) return AppColors.success;
    return AppColors.border;
  }

  /// Border width based on status
  double get _borderWidth {
    if (isMicWell) return 2;
    if (well.needsReview || well.manuallyEdited) return 1.5;
    return 0.5;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border.all(
            color: _borderColor,
            width: _borderWidth,
          ),
        ),
        child: Stack(
          children: [
            // Main well circle
            Center(
              child: FractionallySizedBox(
                widthFactor: 0.75,
                heightFactor: 0.75,
                child: Container(
                  decoration: BoxDecoration(
                    color: _wellColor,
                    shape: BoxShape.circle,
                    border: well.isControlWell
                        ? Border.all(color: Colors.black, width: 2)
                        : null,
                    boxShadow: isMicWell
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: well.isControlWell
                      ? const Center(
                          child: Text(
                            'K',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
            ),
            // Low confidence indicator (warning icon in corner)
            if (well.needsReview)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.warning,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      '!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            // Manually edited indicator (checkmark in corner)
            if (well.manuallyEdited)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      '✓',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
