import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../core/constants/drug_concentrations.dart';
import '../data/models/models.dart';

/// Service for exporting and sharing analysis results
class ExportService {
  /// Generate PDF report for an analysis
  Future<Uint8List> generatePdf(PlateAnalysis analysis) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        header: (context) => _buildHeader(analysis, dateFormat),
        footer: (context) => _buildFooter(context),
        build: (context) => [
          _buildInfoSection(analysis, dateFormat),
          pw.SizedBox(height: 20),
          _buildPlateGrid(analysis),
          pw.SizedBox(height: 20),
          _buildMicResultsTable(analysis),
          pw.SizedBox(height: 20),
          _buildDisclaimer(),
        ],
      ),
    );

    return pdf.save();
  }

  /// Build PDF header
  pw.Widget _buildHeader(PlateAnalysis analysis, DateFormat dateFormat) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 20),
      padding: const pw.EdgeInsets.only(bottom: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(bottom: pw.BorderSide(width: 1)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'MIC Analysis Report',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.Text(
            dateFormat.format(analysis.timestamp),
            style: const pw.TextStyle(fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Build PDF footer
  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      alignment: pw.Alignment.centerRight,
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(fontSize: 10),
      ),
    );
  }

  /// Build info section (analyst, organism, etc.)
  pw.Widget _buildInfoSection(PlateAnalysis analysis, DateFormat dateFormat) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (analysis.analystName != null)
            _buildInfoRow('Analyst:', analysis.analystName!),
          if (analysis.institution != null)
            _buildInfoRow('Institution:', analysis.institution!),
          if (analysis.organism != null)
            _buildInfoRow('Organism:', analysis.organism!),
          _buildInfoRow('Date:', dateFormat.format(analysis.timestamp)),
          _buildInfoRow('Analysis ID:', analysis.id.substring(0, 8)),
        ],
      ),
    );
  }

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 100,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(child: pw.Text(value)),
        ],
      ),
    );
  }

  /// Build plate grid visualization
  pw.Widget _buildPlateGrid(PlateAnalysis analysis) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '96-Well Plate Results',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(),
          ),
          child: pw.Column(
            children: [
              // Column headers
              pw.Row(
                children: [
                  pw.Container(width: 30, height: 20), // Corner
                  ...List.generate(
                    kPlateCols,
                    (col) => pw.Container(
                      width: 30,
                      height: 20,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        '${col + 1}',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                  ),
                ],
              ),
              // Rows
              ...List.generate(kPlateRows, (row) {
                final rowLabel = kRowLabels[row];
                return pw.Row(
                  children: [
                    // Row label
                    pw.Container(
                      width: 30,
                      height: 20,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        '$rowLabel\n${Antifungal.fromRow(rowLabel).code}',
                        style: const pw.TextStyle(fontSize: 6),
                        textAlign: pw.TextAlign.center,
                      ),
                    ),
                    // Wells
                    ...List.generate(kPlateCols, (col) {
                      final well = analysis.wells.firstWhere(
                        (w) => w.row == row && w.column == col,
                        orElse: () => WellResult(
                          row: row,
                          column: col,
                          color: WellColor.partial,
                          growthScore: 0.5,
                        ),
                      );

                      PdfColor wellColor;
                      switch (well.color) {
                        case WellColor.pink:
                          wellColor = PdfColor.fromHex('#EC4899');
                          break;
                        case WellColor.purple:
                          wellColor = PdfColor.fromHex('#8B5CF6');
                          break;
                        case WellColor.partial:
                          wellColor = PdfColor.fromHex('#F59E0B');
                          break;
                      }

                      return pw.Container(
                        width: 30,
                        height: 20,
                        alignment: pw.Alignment.center,
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
                        ),
                        child: pw.Container(
                          width: 14,
                          height: 14,
                          decoration: pw.BoxDecoration(
                            color: wellColor,
                            shape: pw.BoxShape.circle,
                          ),
                        ),
                      );
                    }),
                  ],
                );
              }),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        // Legend
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _buildLegendItem('Growth', PdfColor.fromHex('#EC4899')),
            pw.SizedBox(width: 20),
            _buildLegendItem('Inhibition', PdfColor.fromHex('#8B5CF6')),
            pw.SizedBox(width: 20),
            _buildLegendItem('Uncertain', PdfColor.fromHex('#F59E0B')),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildLegendItem(String label, PdfColor color) {
    return pw.Row(
      children: [
        pw.Container(
          width: 12,
          height: 12,
          decoration: pw.BoxDecoration(
            color: color,
            shape: pw.BoxShape.circle,
          ),
        ),
        pw.SizedBox(width: 4),
        pw.Text(label, style: const pw.TextStyle(fontSize: 8)),
      ],
    );
  }

  /// Build MIC results table
  pw.Widget _buildMicResultsTable(PlateAnalysis analysis) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'MIC Results',
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.TableHelper.fromTextArray(
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          cellAlignment: pw.Alignment.centerLeft,
          cellPadding: const pw.EdgeInsets.all(6),
          headers: ['Drug', 'Code', 'MIC (mg/L)', 'Interpretation'],
          data: analysis.micResults.map((mic) {
            return [
              mic.drugName,
              mic.drugCode,
              mic.micDisplay,
              mic.interpretationLetter,
            ];
          }).toList(),
        ),
      ],
    );
  }

  /// Build disclaimer section
  pw.Widget _buildDisclaimer() {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.yellow50,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.amber),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('*', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Text(
              'Results are for guidance only. Manual verification of MIC values is recommended before clinical decisions.',
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  /// Generate a text summary of the analysis
  String generateTextSummary(PlateAnalysis analysis) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final buffer = StringBuffer();

    buffer.writeln('MIC ANALYSIS REPORT');
    buffer.writeln('='.padRight(40, '='));
    buffer.writeln();

    if (analysis.analystName != null) {
      buffer.writeln('Analyst: ${analysis.analystName}');
    }
    if (analysis.institution != null) {
      buffer.writeln('Institution: ${analysis.institution}');
    }
    if (analysis.organism != null) {
      buffer.writeln('Organism: ${analysis.organism}');
    }
    buffer.writeln('Date: ${dateFormat.format(analysis.timestamp)}');
    buffer.writeln();

    buffer.writeln('MIC RESULTS');
    buffer.writeln('-'.padRight(40, '-'));

    for (final mic in analysis.micResults) {
      final interpretation = mic.interpretationLetter.isNotEmpty
          ? ' (${mic.interpretationLetter})'
          : '';
      buffer.writeln('${mic.drugCode}: ${mic.micDisplay}$interpretation');
    }

    buffer.writeln();
    buffer.writeln('* Results are for guidance only.');

    return buffer.toString();
  }

  /// Save PDF to temporary file and return path
  Future<String> savePdfToTemp(PlateAnalysis analysis) async {
    final pdfBytes = await generatePdf(analysis);
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(analysis.timestamp);
    final filePath = '${tempDir.path}/MIC_Report_$timestamp.pdf';

    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);

    return filePath;
  }

  /// Share PDF report
  Future<void> sharePdf(PlateAnalysis analysis) async {
    final filePath = await savePdfToTemp(analysis);
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'MIC Analysis Report',
    );
  }

  /// Share text summary
  Future<void> shareText(PlateAnalysis analysis) async {
    final summary = generateTextSummary(analysis);
    await Share.share(summary, subject: 'MIC Analysis Results');
  }
}
