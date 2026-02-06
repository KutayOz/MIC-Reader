import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/models.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../providers/history_provider.dart';
import '../../providers/user_provider.dart';
import '../../services/export_service.dart';
import '../../services/image_processing_service.dart';
import '../../services/interpretation_service.dart';
import 'widgets/plate_grid_widget.dart';
import 'widgets/mic_results_table.dart';

class AnalysisScreen extends StatefulWidget {
  final String imagePath;
  final String? patientName;

  const AnalysisScreen({
    super.key,
    required this.imagePath,
    this.patientName,
  });

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  PlateAnalysis? _analysis;
  bool _isLoading = true;
  String? _errorMessage;
  Organism _selectedOrganism = Organism.cAlbicans;
  bool _hasAutoSaved = false;

  @override
  void initState() {
    super.initState();
    _analyzeImage();
  }

  Future<void> _analyzeImage() async {
    // Read provider before async operations
    final userProvider = context.read<UserProvider>();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Wait for UI to update before starting heavy processing
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final service = ImageProcessingService();

      final analysis = await service.analyzeImageAdaptive(
        imagePath: widget.imagePath,
        analystName: userProvider.name,
        institution: userProvider.institution,
      );

      if (mounted) {
        // Calculate initial interpretations with default organism
        final interpretedMicResults = InterpretationService.recalculateInterpretations(
          analysis.micResults,
          _selectedOrganism,
        );

        // Store patient name in notes field
        final analysisWithPatient = analysis.copyWith(
          micResults: interpretedMicResults,
          notes: widget.patientName,
        );

        setState(() {
          _analysis = analysisWithPatient;
          _isLoading = false;
        });

        // Auto-save if enabled
        await _performAutoSave();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Called when organism selection changes
  /// Recalculates all MIC interpretations based on the new organism's breakpoints
  void _onOrganismChanged(Organism organism) {
    if (_analysis == null) return;

    final updatedMicResults = InterpretationService.recalculateInterpretations(
      _analysis!.micResults,
      organism,
    );

    setState(() {
      _selectedOrganism = organism;
      _analysis = _analysis!.copyWith(micResults: updatedMicResults);
    });
  }

  /// Auto-save analysis if enabled in settings
  Future<void> _performAutoSave() async {
    if (_hasAutoSaved || _analysis == null) return;

    final userProvider = context.read<UserProvider>();
    if (!userProvider.autoSaveEnabled) return;

    try {
      final analysisToSave = _analysis!.copyWith(
        organism: _selectedOrganism.fullName,
      );

      await context.read<HistoryProvider>().save(analysisToSave);
      _hasAutoSaved = true;

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.analysisSavedAuto),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Silently fail auto-save, user can still manually save
      debugPrint('Auto-save failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analysisResults),
        actions: [
          if (_analysis != null) ...[
            IconButton(
              icon: const Icon(Icons.save_outlined),
              onPressed: _saveAnalysis,
              tooltip: l10n.save,
            ),
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _shareResults,
              tooltip: l10n.share,
            ),
          ],
        ],
      ),
      body: _buildBody(l10n),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              l10n.analyzing,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                l10n.error,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _analyzeImage,
                child: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    if (_analysis == null) {
      return const Center(child: Text('No analysis data'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grid quality warning
          if (_analysis!.gridQuality != null && !_analysis!.isGridQualityAcceptable)
            _GridQualityWarning(
              quality: _analysis!.gridQuality!,
              onRetry: _analyzeImage,
            ),

          // Control well warning
          if (!_analysis!.isControlValid)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.controlWellWarning,
                      style: const TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),

          // Organism selector
          Text(
            l10n.selectOrganism,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<Organism>(
            initialValue: _selectedOrganism,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: Organism.values.map((org) {
              return DropdownMenuItem(
                value: org,
                child: Text(org.fullName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                _onOrganismChanged(value);
              }
            },
          ),
          const SizedBox(height: 24),

          // Plate visualization
          Text(
            '96-Well Plate',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.tapToEdit,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 12),
          PlateGridWidget(
            wells: _analysis!.wells,
            micResults: _analysis!.micResults,
            onWellTap: _onWellTap,
          ),
          const SizedBox(height: 8),

          // Legend
          _buildLegend(l10n),
          const SizedBox(height: 24),

          // MIC Results table
          Text(
            l10n.micResults,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          MicResultsTable(
            results: _analysis!.micResults,
            organism: _selectedOrganism,
          ),
          const SizedBox(height: 24),

          // Disclaimer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.disclaimer,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(AppLocalizations l10n) {
    return Column(
      children: [
        // Color legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(color: AppColors.growth, label: l10n.growth),
            const SizedBox(width: 16),
            _LegendItem(color: AppColors.inhibition, label: l10n.inhibition),
            const SizedBox(width: 16),
            _LegendItem(color: AppColors.warning, label: l10n.partial),
          ],
        ),
        const SizedBox(height: 8),
        // Confidence indicator legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _IndicatorLegendItem(
              icon: '!',
              color: AppColors.warning,
              label: l10n.needsReview,
            ),
            const SizedBox(width: 16),
            _IndicatorLegendItem(
              icon: '✓',
              color: AppColors.success,
              label: l10n.manuallyEdited,
            ),
          ],
        ),
      ],
    );
  }

  void _onWellTap(WellResult well) {
    final l10n = AppLocalizations.of(context)!;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${l10n.editWells}: ${well.wellId}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Current status
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: well.color == WellColor.pink
                        ? AppColors.growth
                        : well.color == WellColor.purple
                            ? AppColors.inhibition
                            : AppColors.warning,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  well.color == WellColor.pink
                      ? l10n.growth
                      : well.color == WellColor.purple
                          ? l10n.inhibition
                          : l10n.partial,
                  style: Theme.of(dialogContext).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${l10n.rawConfidence}: ${(well.confidence * 100).toStringAsFixed(0)}%',
              style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            if (well.needsReview)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.needsReview,
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),

            // Change color options
            Text(
              l10n.changeColor,
              style: Theme.of(dialogContext).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ColorChoiceButton(
                    color: AppColors.growth,
                    label: l10n.growth,
                    isSelected: well.color == WellColor.pink,
                    onTap: () => _updateWellColor(well, WellColor.pink),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ColorChoiceButton(
                    color: AppColors.inhibition,
                    label: l10n.inhibition,
                    isSelected: well.color == WellColor.purple,
                    onTap: () => _updateWellColor(well, WellColor.purple),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
  }

  void _updateWellColor(WellResult well, WellColor newColor) {
    if (well.color == newColor) {
      Navigator.pop(context);
      return;
    }

    // Create updated well
    final updatedWell = well.copyWith(
      color: newColor,
      manuallyEdited: true,
      // Adjust growth score based on selection
      growthScore: newColor == WellColor.pink ? 0.95 : 0.05,
    );

    // Update wells list
    final updatedWells = _analysis!.wells.map((w) {
      if (w.row == well.row && w.column == well.column) {
        return updatedWell;
      }
      return w;
    }).toList();

    // Recalculate MIC values
    final service = ImageProcessingService();
    final updatedMicResults = service.recalculateMic(updatedWells);

    setState(() {
      _analysis = _analysis!.copyWith(
        wells: updatedWells,
        micResults: updatedMicResults,
      );
    });

    Navigator.pop(context);

    // Show confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${well.wellId} updated'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _saveAnalysis() async {
    if (_analysis == null) return;

    final l10n = AppLocalizations.of(context)!;

    // Check if already auto-saved
    if (_hasAutoSaved) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.analysisSavedAuto),
            backgroundColor: AppColors.success,
          ),
        );
      }
      return;
    }

    try {
      // Update analysis with selected organism
      final analysisToSave = _analysis!.copyWith(
        organism: _selectedOrganism.fullName,
      );

      await context.read<HistoryProvider>().save(analysisToSave);
      _hasAutoSaved = true; // Prevent duplicate saves

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.save} - Success'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _shareResults() {
    if (_analysis == null) return;

    final l10n = AppLocalizations.of(context)!;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.shareResults,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.exportFormat,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 12),
            _ShareOption(
              icon: Icons.picture_as_pdf,
              title: l10n.pdfReport,
              subtitle: l10n.pdfReportDesc,
              onTap: () {
                Navigator.pop(context);
                _sharePdf();
              },
            ),
            const SizedBox(height: 8),
            _ShareOption(
              icon: Icons.text_snippet_outlined,
              title: l10n.textOnly,
              subtitle: l10n.textOnlyDesc,
              onTap: () {
                Navigator.pop(context);
                _shareText();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sharePdf() async {
    if (_analysis == null) return;

    final l10n = AppLocalizations.of(context)!;

    // Update analysis with selected organism before sharing
    final analysisToShare = _analysis!.copyWith(
      organism: _selectedOrganism.fullName,
    );

    try {
      final exportService = ExportService();
      await exportService.sharePdf(analysisToShare);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _shareText() async {
    if (_analysis == null) return;

    final l10n = AppLocalizations.of(context)!;

    // Update analysis with selected organism before sharing
    final analysisToShare = _analysis!.copyWith(
      organism: _selectedOrganism.fullName,
    );

    try {
      final exportService = ExportService();
      await exportService.shareText(analysisToShare);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _IndicatorLegendItem extends StatelessWidget {
  final String icon;
  final Color color;
  final String label;

  const _IndicatorLegendItem({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1),
          ),
          child: Center(
            child: Text(
              icon,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ColorChoiceButton extends StatelessWidget {
  final Color color;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorChoiceButton({
    required this.color,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : AppColors.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShareOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ShareOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Warning widget for grid quality issues
class _GridQualityWarning extends StatelessWidget {
  final GridQuality quality;
  final VoidCallback onRetry;

  const _GridQualityWarning({
    required this.quality,
    required this.onRetry,
  });

  Color get _borderColor {
    if (quality.needsManualReview) return AppColors.danger;
    if (quality.isMarginal) return AppColors.warning;
    return AppColors.textSecondary;
  }

  Color get _backgroundColor {
    if (quality.needsManualReview) return AppColors.danger.withValues(alpha: 0.1);
    if (quality.isMarginal) return AppColors.warning.withValues(alpha: 0.1);
    return AppColors.textSecondary.withValues(alpha: 0.1);
  }

  IconData get _icon {
    if (quality.needsManualReview) return Icons.error_outline;
    return Icons.warning_amber_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(_icon, color: _borderColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Grid Detection: ${quality.qualityLevel}',
                      style: TextStyle(
                        color: _borderColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Try taking the photo again with better lighting',
                      style: TextStyle(
                        color: _borderColor.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Retry button
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Take New Photo'),
                style: TextButton.styleFrom(
                  foregroundColor: _borderColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
