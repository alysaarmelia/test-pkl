import 'dart:math';
import 'dart:typed_data';

import '../models/material_request.dart';
import 'material_request_doc_builder.dart';
import 'material_request_pdf_builder.dart';

class MaterialRequestDocumentBundle {
  MaterialRequestDocumentBundle({
    required this.baseFileName,
    required this.docxBytes,
    required this.pdfBytes,
    required this.docFileName,
    required this.pdfFileName,
  });

  final String baseFileName;
  final Uint8List docxBytes;
  final Uint8List pdfBytes;
  final String docFileName;
  final String pdfFileName;
}

class MaterialRequestDocumentService {
  MaterialRequestDocumentService({
    MaterialRequestDocBuilder? docBuilder,
    MaterialRequestPdfBuilder? pdfBuilder,
  })  : _docBuilder = docBuilder ?? MaterialRequestDocBuilder(),
        _pdfBuilder = pdfBuilder ?? MaterialRequestPdfBuilder();

  final MaterialRequestDocBuilder _docBuilder;
  final MaterialRequestPdfBuilder _pdfBuilder;

  Future<MaterialRequestDocumentBundle> generate(
    MaterialRequestDraft draft, {
    String? baseFileName,
  }) async {
    final sanitizedBase =
        (baseFileName ?? _generateBaseFileName(draft)).trim().isEmpty
            ? _fallbackBaseName()
            : _sanitizeBase(baseFileName ?? _generateBaseFileName(draft));

    final docFileName = '$sanitizedBase.docx';
    final pdfFileName = '$sanitizedBase.pdf';
    final docxBytes = await _docBuilder.build(draft);
    final pdfBytes = await _pdfBuilder.build(draft);

    return MaterialRequestDocumentBundle(
      baseFileName: sanitizedBase,
      docxBytes: docxBytes,
      pdfBytes: pdfBytes,
      docFileName: docFileName,
      pdfFileName: pdfFileName,
    );
  }

  String _generateBaseFileName(MaterialRequestDraft draft) {
    final timestamp = DateTime.now().toLocal();
    final stamp =
        '${timestamp.year.toString().padLeft(4, '0')}${timestamp.month.toString().padLeft(2, '0')}${timestamp.day.toString().padLeft(2, '0')}-${timestamp.hour.toString().padLeft(2, '0')}${timestamp.minute.toString().padLeft(2, '0')}${timestamp.second.toString().padLeft(2, '0')}';
    final project = _sanitizeSegment(draft.projectName);
    final company = _sanitizeSegment(draft.companyName);
    final parts = [
      'order-bahan-material',
      if (project.isNotEmpty) project,
      if (company.isNotEmpty) company,
      stamp,
    ];
    return parts.join('-');
  }

  String _sanitizeSegment(String value) {
    final result = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp('-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return result.length > 24 ? result.substring(0, 24) : result;
  }

  String _sanitizeBase(String value) {
    final sanitized = value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\-]+'), '-')
        .replaceAll(RegExp('-{2,}'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return sanitized.isEmpty ? _fallbackBaseName() : sanitized;
  }

  String _fallbackBaseName() {
    final random = Random();
    final suffix = random.nextInt(9999).toString().padLeft(4, '0');
    return 'order-bahan-material-$suffix';
  }
}
