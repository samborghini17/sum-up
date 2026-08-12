import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

class PdfExportService {
  static Future<String> generateAndSavePdf({
    required String videoName,
    required String summary,
    required List<Map<String, String>> timestamps,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            _buildHeader(videoName),
            pw.SizedBox(height: 24),
            _buildSectionTitle('Kernzusammenfassung'),
            pw.Paragraph(text: summary, style: const pw.TextStyle(fontSize: 12, lineSpacing: 1.5)),
            pw.SizedBox(height: 24),
            _buildSectionTitle('Wichtige Timecodes'),
            ...timestamps.map((ts) => _buildTimecodeItem(ts['time']!, ts['title']!)).toList(),
          ];
        },
      ),
    );

    // Save the file
    Directory? directory;
    if (Platform.isWindows) {
      directory = await getDownloadsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }

    final sanitizedName = videoName.replaceAll(RegExp(r'[^\w\s]+'), '').replaceAll(' ', '_');
    final String path = '${directory?.path}\\${sanitizedName}_Analyse.pdf';
    final file = File(path);
    await file.writeAsBytes(await pdf.save());
    return path;
  }

  static pw.Widget _buildHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'KREATIV INSTITUT.OWL',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: const PdfColor(0.33, 0.99, 0.15), // Neon Green approx
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          'KI Videoanalyse Report',
          style: pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
        ),
        pw.Divider(),
        pw.SizedBox(height: 16),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Text(
        title,
        style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: const PdfColor(0.33, 0.99, 0.15)),
      ),
    );
  }

  static pw.Widget _buildTimecodeItem(String time, String title) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 8),
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(time, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
          pw.SizedBox(width: 16),
          pw.Expanded(child: pw.Text(title, style: const pw.TextStyle(color: PdfColors.black))),
        ],
      ),
    );
  }
}
