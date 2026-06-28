// ignore_for_file: avoid_print

import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// `store/legal/*.md` → `store/legal/pdf/*.pdf` (노란 형광펜 = REVIEW 마커)
///
/// 실행: dart run tool/generate_legal_pdfs.dart
void main() async {
  final sourceDir = Directory('store/legal');
  final pdfDir = Directory('store/legal/pdf');
  final assetsDir = Directory('assets/legal');

  if (!sourceDir.existsSync()) {
    stderr.writeln('store/legal 디렉터리가 없습니다.');
    exit(1);
  }

  pdfDir.createSync(recursive: true);
  assetsDir.createSync(recursive: true);

  final mdFiles = sourceDir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.md') && !f.path.endsWith('README.md'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  if (mdFiles.isEmpty) {
    stderr.writeln('변환할 .md 파일이 없습니다.');
    exit(1);
  }

  for (final file in mdFiles) {
    final name = file.uri.pathSegments.last;
    final raw = await file.readAsString();
    final pdfBytes = await _buildPdf(raw, title: name.replaceAll('.md', ''));

    final pdfPath = '${pdfDir.path}/${name.replaceAll('.md', '.pdf')}';
    await File(pdfPath).writeAsBytes(pdfBytes);

    await file.copy('${assetsDir.path}/$name');
    print('✓ $name → $pdfPath');
  }

  print('\n${mdFiles.length}개 PDF 생성 완료: store/legal/pdf/');
  print('assets/legal/ 동기화 완료');
}

final _reviewPattern = RegExp(
  r'\[\[REVIEW:([^\]]*)\]\]([\s\S]*?)\[\[/REVIEW\]\]',
);

Future<List<int>> _buildPdf(String raw, {required String title}) async {
  final doc = pw.Document();
  final reviewCount = _reviewPattern.allMatches(raw).length;
  final blocks = _splitBlocks(raw);

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(40),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Divider(color: PdfColors.grey300, thickness: 0.5),
        ],
      ),
      footer: (context) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            '초안 — 법무 검토 전 (REVIEW $reviewCount건)',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
          pw.Text(
            '${context.pageNumber} / ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
      build: (context) => [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromHex('#FFF9C4'),
            border: pw.Border.all(color: PdfColor.fromHex('#F9A825')),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Text(
            '노란 형광펜 구간은 법무 검토 전 반드시 수정·확인해야 하는 항목입니다. '
            '그대로 사용할 수 없습니다.',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
        pw.SizedBox(height: 14),
        for (final block in blocks) ...[
          pw.RichText(
            text: pw.TextSpan(
              children: _parseSpans(block),
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 4),
            ),
          ),
          pw.SizedBox(height: 6),
        ],
      ],
    ),
  );

  return doc.save();
}

List<String> _splitBlocks(String raw) {
  final lines = raw.split('\n');
  final blocks = <String>[];
  final buffer = StringBuffer();

  for (final line in lines) {
    if (line.trim().isEmpty) {
      if (buffer.isNotEmpty) {
        blocks.add(buffer.toString().trimRight());
        buffer.clear();
      }
      continue;
    }
    if (buffer.isNotEmpty) buffer.writeln();
    buffer.write(line);
  }

  if (buffer.isNotEmpty) {
    blocks.add(buffer.toString().trimRight());
  }

  return blocks;
}

List<pw.TextSpan> _parseSpans(String raw) {
  const baseStyle = pw.TextStyle(fontSize: 10, lineSpacing: 4);
  final reviewStyle = pw.TextStyle(
    fontSize: 10,
    lineSpacing: 4,
    background: pw.BoxDecoration(color: PdfColor.fromHex('#FFF59D')),
    color: PdfColor.fromHex('#5D4037'),
    fontWeight: pw.FontWeight.bold,
  );

  final spans = <pw.TextSpan>[];
  var cursor = 0;

  for (final match in _reviewPattern.allMatches(raw)) {
    if (match.start > cursor) {
      spans.add(pw.TextSpan(
        text: raw.substring(cursor, match.start),
        style: baseStyle,
      ));
    }

    final note = match.group(1)?.trim() ?? '';
    final body = match.group(2) ?? '';
    final reviewText = note.isEmpty ? body : '[$note] $body';

    spans.add(pw.TextSpan(text: reviewText, style: reviewStyle));
    cursor = match.end;
  }

  if (cursor < raw.length) {
    spans.add(pw.TextSpan(
      text: raw.substring(cursor),
      style: baseStyle,
    ));
  }

  return spans;
}
