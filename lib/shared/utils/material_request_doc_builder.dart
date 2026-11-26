import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:xml/xml.dart';

import '../models/material_request.dart';

class MaterialRequestDocBuilder {
  static const _templatePath =
      'lib/app/assets/word/ORDER BAHAN MATERIAL.docx';
  static const _wNs =
      'http://schemas.openxmlformats.org/wordprocessingml/2006/main';

  Future<Uint8List> build(MaterialRequestDraft draft) async {
    final templateData = await rootBundle.load(_templatePath);
    final archive = ZipDecoder().decodeBytes(
      templateData.buffer.asUint8List(),
      verify: false,
    );

    final documentFile = archive.files
        .firstWhere((file) => file.name == 'word/document.xml');
    final documentXml =
        utf8.decode(documentFile.content as List<int>, allowMalformed: true);
    final document = XmlDocument.parse(documentXml);

    _injectHeaderFields(document, draft);
    _injectItems(document, draft.items);
    _injectSignatures(document, draft);

    final updatedXml = document.toXmlString();
    final encoder = ZipEncoder();
    final updatedArchive = Archive();

    for (final file in archive.files) {
      if (file.name == 'word/document.xml') {
        final bytes = utf8.encode(updatedXml);
        final updatedFile = ArchiveFile(file.name, bytes.length, bytes)
          ..lastModTime = file.lastModTime
          ..mode = file.mode
          ..compression = file.compression
          ..compressionLevel = file.compressionLevel
          ..comment = file.comment;
        updatedArchive.addFile(updatedFile);
      } else {
        updatedArchive.addFile(file);
      }
    }

    final encoded = encoder.encode(updatedArchive);
    if (encoded == null) {
      throw Exception('Gagal membuat dokumen Word.');
    }
    return Uint8List.fromList(encoded);
  }

  void _injectHeaderFields(XmlDocument document, MaterialRequestDraft draft) {
    final textNodes = document
        .findAllElements('w:t', namespace: _wNs)
        .cast<XmlElement>()
        .toList(growable: false);

    XmlElement? findNode(bool Function(XmlElement node) predicate,
        {int occurrence = 0}) {
      var count = 0;
      for (final node in textNodes) {
        if (predicate(node)) {
          if (count == occurrence) {
            return node;
          }
          count++;
        }
      }
      return null;
    }

    XmlElement? nextNode(XmlElement current, int offset) {
      final index = textNodes.indexOf(current);
      if (index == -1) return null;
      final targetIndex = index + offset;
      if (targetIndex < 0 || targetIndex >= textNodes.length) return null;
      return textNodes[targetIndex];
    }

    void setText(XmlElement? node, String value) {
      if (node == null) return;
      node.children
        ..clear()
        ..add(XmlText(value));
    }

    XmlElement? _paragraphForNode(XmlElement? node) {
      XmlNode? current = node;
      while (current != null) {
        if (current is XmlElement && current.name.local == 'p') {
          return current;
        }
        current = current.parent;
      }
      return null;
    }

    void ensureBottomBorder(XmlElement? paragraph, {int size = 12}) {
      if (paragraph == null) return;
      var pPr = paragraph.getElement('pPr', namespace: _wNs);
      if (pPr == null) {
        pPr = XmlElement(XmlName('pPr', 'w'));
        paragraph.children.insert(0, pPr);
      }
      var borders = pPr.getElement('pBdr', namespace: _wNs);
      if (borders == null) {
        borders = XmlElement(XmlName('pBdr', 'w'));
        pPr.children.add(borders);
      }
      borders.children.removeWhere(
        (node) =>
            node is XmlElement && node.name.local == 'bottom',
      );
      borders.children.add(
        XmlElement(
          XmlName('bottom', 'w'),
          [
            XmlAttribute(XmlName('val', 'w'), 'single'),
            XmlAttribute(XmlName('sz', 'w'), size.toString()),
            XmlAttribute(XmlName('space', 'w'), '1'),
            XmlAttribute(XmlName('color', 'w'), 'auto'),
          ],
        ),
      );
    }

    void setParagraphAlignment(XmlElement? paragraph, String alignment) {
      if (paragraph == null) return;
      var pPr = paragraph.getElement('pPr', namespace: _wNs);
      if (pPr == null) {
        pPr = XmlElement(XmlName('pPr', 'w'));
        paragraph.children.insert(0, pPr);
      }
      pPr.children.removeWhere(
        (node) =>
            node is XmlElement && node.name.local == 'jc',
      );
      pPr.children.insert(
        0,
        XmlElement(
          XmlName('jc', 'w'),
          [XmlAttribute(XmlName('val', 'w'), alignment)],
        ),
      );
    }

    void ensureTabStop(
      XmlElement paragraph, {
      required String alignment,
      required int position,
    }) {
      var pPr = paragraph.getElement('pPr', namespace: _wNs);
      if (pPr == null) {
        pPr = XmlElement(XmlName('pPr', 'w'));
        paragraph.children.insert(0, pPr);
      }
      var tabs = pPr.getElement('tabs', namespace: _wNs);
      if (tabs == null) {
        tabs = XmlElement(XmlName('tabs', 'w'));
        pPr.children.add(tabs);
      }
      final exists = tabs.children.any(
        (node) =>
            node is XmlElement &&
            node.name.local == 'tab' &&
            node.getAttribute('val', namespace: _wNs) == alignment &&
            node.getAttribute('pos', namespace: _wNs) == position.toString(),
      );
      if (!exists) {
        tabs.children.add(
          XmlElement(
            XmlName('tab', 'w'),
            [
              XmlAttribute(XmlName('val', 'w'), alignment),
              XmlAttribute(XmlName('pos', 'w'), position.toString()),
            ],
          ),
        );
      }
    }

    XmlElement _buildStyledRun(
      String text, {
      bool bold = false,
    }) {
      final runChildren = <XmlNode>[];
      if (bold) {
        runChildren.add(
          XmlElement(
            XmlName('rPr', 'w'),
            [],
            [
              XmlElement(XmlName('b', 'w')),
              XmlElement(XmlName('bCs', 'w')),
            ],
          ),
        );
      }
      runChildren.add(
        XmlElement(
          XmlName('t', 'w'),
          [XmlAttribute(XmlName('space', 'xml'), 'preserve')],
          [XmlText(text)],
        ),
      );
      return XmlElement(XmlName('r', 'w'), [], runChildren);
    }

    XmlElement _buildTabRun() {
      return XmlElement(
        XmlName('r', 'w'),
        [],
        [
          XmlElement(XmlName('tab', 'w')),
        ],
      );
    }

    final companyLabel =
        findNode((node) => node.text.trim().startsWith('PT/CV'));
    if (companyLabel != null) {
      final companyValueNode = nextNode(companyLabel, 2);
      setText(companyValueNode, ' ${draft.companyName}');
    }

    final dateLabel =
        findNode((node) => node.text.trim().startsWith('TANGGAL'));
    final projectLabel =
        findNode((node) => node.text.trim().startsWith('PROYEK'));
    final dateParagraph = _paragraphForNode(dateLabel);
    final projectParagraph = _paragraphForNode(projectLabel);

    if (dateLabel != null &&
        projectLabel != null &&
        dateParagraph != null &&
        dateParagraph == projectParagraph) {
      final formattedDate = _formatDate(draft.requestDate);
      final projectText =
          draft.projectName.trim().isEmpty ? '-' : draft.projectName.trim();

      dateParagraph.children.clear();
      dateParagraph.children.add(XmlElement(XmlName('pPr', 'w')));

      setParagraphAlignment(dateParagraph, 'left');
      ensureBottomBorder(dateParagraph);
      ensureTabStop(
        dateParagraph,
        alignment: 'right',
        position: 9000,
      );

      dateParagraph.children.addAll([
        _buildStyledRun('TANGGAL :', bold: true),
        _buildStyledRun(' $formattedDate'),
        _buildTabRun(),
        _buildStyledRun('PROYEK :', bold: true),
        _buildStyledRun(' $projectText'),
      ]);
    } else {
      if (dateLabel != null) {
        final dateValueNode = nextNode(dateLabel, 1);
        setText(dateValueNode, ' ${_formatDate(draft.requestDate)}');
        final paragraph = _paragraphForNode(dateLabel);
        ensureBottomBorder(paragraph);
        setParagraphAlignment(paragraph, 'left');
      }

      if (projectLabel != null) {
        final projectValueNode = nextNode(projectLabel, 1);
        final projectText =
            draft.projectName.trim().isEmpty ? '-' : draft.projectName.trim();
        setText(projectValueNode, ' $projectText');
        final paragraph = _paragraphForNode(projectLabel);
        ensureBottomBorder(paragraph);
        setParagraphAlignment(paragraph, 'right');
      }
    }

    final titleNode =
        findNode((node) => node.text.trim().toUpperCase() == 'ORDER BAHAN');
    ensureBottomBorder(_paragraphForNode(titleNode), size: 18);
  }

  void _injectItems(
    XmlDocument document,
    List<MaterialRequestItem> items,
  ) {
    if (items.isEmpty) return;
    final tables =
        document.findAllElements('w:tbl', namespace: _wNs).toList(growable: false);
    if (tables.isEmpty) return;

    final table = tables.first;
    final rows = table.findElements('w:tr', namespace: _wNs).toList();
    if (rows.isEmpty) return;

    final headerRow = rows.first;
    for (final row in rows.skip(1)) {
      row.parent?.children.remove(row);
    }

    final headerIndex = table.children.indexOf(headerRow);
    var insertIndex = headerIndex + 1;

    for (final item in items) {
      final row = _buildItemRow(item);
      table.children.insert(insertIndex, row);
      insertIndex++;
    }
  }

  XmlElement _buildItemRow(MaterialRequestItem item) {
    final rowChildren = <XmlNode>[
      _buildCell(item.no.toString(), width: 562, alignment: 'center'),
      _buildCell(item.name, width: 4111, alignment: 'center'),
      _buildCell(item.quantity, width: 4677, alignment: 'center'),
    ];
    return XmlElement(XmlName('tr', 'w'), [], rowChildren);
  }

  XmlElement _buildCell(
    String text, {
    required int width,
    required String alignment,
  }) {
    final attributes = <XmlAttribute>[
      XmlAttribute(XmlName('w', 'w'), width.toString()),
      XmlAttribute(XmlName('type', 'w'), 'dxa'),
    ];

    final tcPr = XmlElement(XmlName('tcPr', 'w'), [], [
      XmlElement(XmlName('tcW', 'w'), attributes, const []),
    ]);

    final pPrChildren = <XmlNode>[];
    if (alignment != 'left') {
      pPrChildren.add(
        XmlElement(
          XmlName('jc', 'w'),
          [XmlAttribute(XmlName('val', 'w'), alignment)],
        ),
      );
    }

    final pPr = XmlElement(XmlName('pPr', 'w'), [], pPrChildren);
    final run = XmlElement(XmlName('r', 'w'), [], [
      XmlElement(
        XmlName('t', 'w'),
        [XmlAttribute(XmlName('space', 'xml'), 'preserve')],
        [XmlText(text)],
      )
    ]);
    final paragraph = XmlElement(XmlName('p', 'w'), [], [pPr, run]);

    return XmlElement(XmlName('tc', 'w'), [], [tcPr, paragraph]);
  }

  void _injectSignatures(
    XmlDocument document,
    MaterialRequestDraft draft,
  ) {
    final nodes = document
        .findAllElements('w:t', namespace: _wNs)
        .toList(growable: false);
    XmlElement? firstSignature;
    XmlElement? secondSignature;
    var occurrence = 0;
    for (final node in nodes) {
      if (node.text == 'Nama user') {
        if (occurrence == 0) {
          firstSignature = node;
        } else if (occurrence == 1) {
          secondSignature = node;
        }
        occurrence++;
      }
    }
    if (firstSignature != null) {
      firstSignature.children
        ..clear()
        ..add(XmlText(draft.requesterName));
    }
    if (secondSignature != null) {
      secondSignature.children
        ..clear()
        ..add(XmlText(draft.approverName ?? ''));
    }
  }

  String _formatDate(DateTime date) {
    final d = date.toLocal();
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    final year = d.year.toString().padLeft(4, '0');
    return '$day-$month-$year';
  }
}
