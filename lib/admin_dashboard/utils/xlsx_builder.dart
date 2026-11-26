import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

class SimpleXlsxBuilder {
  SimpleXlsxBuilder({
    required this.rows,
    this.sheetName = 'Sheet1',
    this.title,
  });

  final List<List<String>> rows;
  final String sheetName;
  final String? title;

  Uint8List build() {
    final archive = Archive()
      ..addFile(ArchiveFile.string(
        '[Content_Types].xml',
        _contentTypesXml,
      ))
      ..addFile(ArchiveFile.string(
        '_rels/.rels',
        _relsXml,
      ))
      ..addFile(ArchiveFile.string(
        'xl/_rels/workbook.xml.rels',
        _workbookRelsXml,
      ))
      ..addFile(ArchiveFile.string(
        'xl/styles.xml',
        _stylesXml,
      ))
      ..addFile(ArchiveFile.string(
        'xl/workbook.xml',
        _workbookXml(sheetName),
      ))
      ..addFile(ArchiveFile.string(
        'xl/worksheets/sheet1.xml',
        _sheetXml(rows, title),
      ));

    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    return Uint8List.fromList(bytes);
  }

  static const String _contentTypesXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
    <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
    <Default Extension="xml" ContentType="application/xml"/>
    <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
    <Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>
    <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>
''';

  static const String _relsXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>
''';

  static const String _workbookRelsXml = '''
<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
    <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
    <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>
</Relationships>
''';

  static String _workbookXml(String sheetName) => '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
  <sheets>
    <sheet name="${_escapeXml(sheetName)}" sheetId="1" r:id="rId1"/>
  </sheets>
</workbook>
''';

  static String _sheetXml(List<List<String>> rows, String? title) {
    final columnCount = rows.isNotEmpty ? rows.first.length : 1;
    final buffer = StringBuffer()
      ..writeln('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
      ..writeln('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
      ..writeln('<sheetData>');

    var currentRow = 1;
    bool wroteTitle = false;
    if (title != null && title.isNotEmpty) {
      final cellRef = _cellRef(currentRow, 1);
      buffer
        ..write('<row r="$currentRow">')
        ..write('<c r="$cellRef" t="inlineStr" s="1"><is><t>')
        ..write(_escapeXml(title))
        ..write('</t></is></c>')
        ..writeln('</row>');
      currentRow++;
      wroteTitle = true;
    }

    for (var r = 0; r < rows.length; r++) {
      final row = rows[r];
      final rowIndex = currentRow + r;
      buffer.write('<row r="$rowIndex">');
      for (var c = 0; c < row.length; c++) {
        final cellRef = _cellRef(rowIndex, c + 1);
        final value = _escapeXml(row[c]);
        buffer
          ..write('<c r="$cellRef" t="inlineStr"><is><t>')
          ..write(value)
          ..write('</t></is></c>');
      }
      buffer.writeln('</row>');
    }

    buffer.writeln('</sheetData>');

    if (wroteTitle && columnCount > 1) {
      final endCol = _columnName(columnCount);
      buffer.writeln(
        '<mergeCells count="1"><mergeCell ref="A1:${endCol}1"/></mergeCells>',
      );
    }

    buffer.writeln('</worksheet>');

    return buffer.toString();
  }

  static String _cellRef(int row, int col) => '${_columnName(col)}$row';

  static String _columnName(int index) {
    var n = index;
    final chars = <String>[];
    while (n > 0) {
      n--;
      chars.insert(0, String.fromCharCode(65 + (n % 26)));
      n ~/= 26;
    }
    return chars.join();
  }

  static String _escapeXml(String input) {
    return const HtmlEscape(HtmlEscapeMode.element).convert(input);
  }

  static const String _stylesXml = '''
<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <fonts count="2">
    <font/>
    <font><b/><sz val="13"/><color rgb="FF000000"/><name val="Arial"/></font>
  </fonts>
  <fills count="1">
    <fill><patternFill patternType="none"/></fill>
  </fills>
  <borders count="1">
    <border><left/><right/><top/><bottom/><diagonal/></border>
  </borders>
  <cellStyleXfs count="1">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0"/>
  </cellStyleXfs>
  <cellXfs count="2">
    <xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
    <xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0">
      <alignment horizontal="center"/>
    </xf>
  </cellXfs>
  <cellStyles count="1">
    <cellStyle name="Normal" xfId="0" builtinId="0"/>
  </cellStyles>
</styleSheet>
''';
}
