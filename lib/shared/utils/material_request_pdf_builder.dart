import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/material_request.dart';

class MaterialRequestPdfBuilder {
  Future<Uint8List> build(MaterialRequestDraft draft) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(32, 40, 32, 40),
        build: (context) => _buildContent(draft),
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildContent(MaterialRequestDraft draft) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Center(
          child: pw.Text(
            'ORDER BAHAN',
            style: pw.TextStyle(
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 6),
        _buildSeparator(),
        pw.SizedBox(height: 12),
        _buildInfoSection(draft),
        pw.SizedBox(height: 20),
        _buildItemsTable(draft.items),
        pw.SizedBox(height: 40),
        _buildSignatureSection(draft),
      ],
    );
  }

  pw.Widget _buildInfoSection(MaterialRequestDraft draft) {
    final infoStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final valueStyle = pw.TextStyle(fontWeight: pw.FontWeight.normal);
    final separator = _buildSeparator();
    final projectName = draft.projectName.trim().isEmpty
        ? '-'
        : draft.projectName.trim();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Text('PT/CV : ', style: infoStyle),
            pw.Expanded(
              child: pw.Text(draft.companyName, style: valueStyle),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: 'TANGGAL :', style: infoStyle),
                  pw.TextSpan(
                    text: ' ${_formatDate(draft.requestDate)}',
                    style: valueStyle,
                  ),
                ],
              ),
            ),
            pw.Spacer(),
            pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(text: 'PROYEK :', style: infoStyle),
                  pw.TextSpan(text: ' $projectName', style: valueStyle),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        separator,
      ],
    );
  }

  pw.Widget _buildItemsTable(List<MaterialRequestItem> items) {
    final headers = ['NO', 'JENIS BARANG', 'JUMLAH BARANG', 'STATUS'];
    final headerStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.bold,
    );
    final cellStyle = pw.TextStyle(
      fontWeight: pw.FontWeight.normal,
    );

    return pw.Table(
      border: pw.TableBorder.all(width: 1),
      columnWidths: {
        0: const pw.FlexColumnWidth(1),
        1: const pw.FlexColumnWidth(4.6),
        2: const pw.FlexColumnWidth(2.6),
        3: const pw.FlexColumnWidth(2.4),
      },
      children: [
        pw.TableRow(
          decoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE0E0E0)),
          children: headers
              .map(
                (title) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: pw.Center(
                    child: pw.Text(title, style: headerStyle),
                  ),
                ),
              )
              .toList(growable: false),
        ),
        ...items.map(
          (item) => pw.TableRow(
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 6,
                ),
                child: pw.Center(
                  child: pw.Text(item.no.toString(), style: cellStyle),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 6,
                ),
                child: pw.Center(
                  child: pw.Text(
                    item.name,
                    style: cellStyle,
                    textAlign: pw.TextAlign.center,
                  ),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 6,
                ),
                child: pw.Center(
                  child: pw.Text(item.quantity, style: cellStyle),
                ),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 6,
                ),
                child: pw.Center(
                  child: pw.Text(
                    _statusLabel(item.status),
                    style: cellStyle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSeparator() {
    return pw.Container(
      height: 1.2,
      color: PdfColor.fromInt(0xFF555555),
    );
  }

  pw.Widget _buildSignatureSection(MaterialRequestDraft draft) {
    final titleStyle = pw.TextStyle(fontWeight: pw.FontWeight.bold);
    final valueStyle = pw.TextStyle(fontSize: 12);
    final spacer = pw.SizedBox(height: 48);

    final requesterColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('Mengetahui', style: titleStyle),
        pw.Text('Pengorder lapangan', style: valueStyle),
        spacer,
        pw.Text(_formatDisplayName(draft.requesterName), style: valueStyle),
      ],
    );

    final approverColumn = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text('Mengetahui', style: titleStyle),
        pw.Text('Dari kantor', style: valueStyle),
        spacer,
        pw.Text(_formatDisplayName(draft.approverName), style: valueStyle),
      ],
    );

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
      children: [
        pw.Expanded(child: requesterColumn),
        pw.SizedBox(width: 32),
        pw.Expanded(child: approverColumn),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString().padLeft(4, '0');
    return '$day-$month-$year';
  }

  String _statusLabel(String status) {
    switch (status) {
      case MaterialRequestItemStatus.approved:
        return 'Disetujui';
      case MaterialRequestItemStatus.pending:
      default:
        return 'Pending';
    }
  }

  String _formatDisplayName(String? name) {
    if (name == null || name.isEmpty) return '';
    
    // If it contains an email, extract the username part
    if (name.contains('@')) {
      name = name.split('@')[0];
    }
    
    // Replace common separators with space
    name = name.replaceAll(RegExp(r'[._-]'), ' ');
    
    // Split into words and capitalize each word
    final words = name.split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
        .toList();
    
    return words.join(' ');
  }
}
