import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:map/features/corporate/domain/services/roi_metrics_service.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// ROI 대시보드 PDF — 출근 확인 수수료 대비 절감 포함
class RoiPdfService {
  const RoiPdfService();

  static final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');
  static final _krw = NumberFormat('#,###');

  Future<Uint8List> buildPdf({
    required String companyName,
    required RoiMetrics metrics,
    String? tierLabel,
    List<BranchRoiRow> branchRows = const [],
  }) async {
    final font = await PdfGoogleFonts.notoSansKRRegular();
    final fontBold = await PdfGoogleFonts.notoSansKRBold();

    pw.Widget row(String label, String value, {bool bold = false}) =>
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 130,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    font: font,
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    font: bold ? fontBold : font,
                    fontSize: bold ? 12 : 10,
                  ),
                ),
              ),
            ],
          ),
        );

    final doc = pw.Document(title: 'ROI 리포트', author: companyName);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            '채용 ROI · 아웃소싱 대체 리포트',
            style: pw.TextStyle(font: fontBold, fontSize: 18),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '$companyName · ${tierLabel ?? ''} · ${metrics.periodLabel} · '
            '${_dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          if (metrics.commissionSavingsVsBasicKrw > 0) ...[
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    '출근 확인(10,000원/건) 대비 수수료 절감',
                    style: pw.TextStyle(font: fontBold, fontSize: 12),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '${_krw.format(metrics.commissionSavingsVsBasicKrw)}원 절약',
                    style: pw.TextStyle(font: fontBold, fontSize: 16),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 14),
          ],
          row('지원 건수', '${metrics.applications}건'),
          row('출근 확인', '${metrics.checkIns}건'),
          row('PUSH 비용', '${_krw.format(metrics.pushSpendKrw)}원'),
          row('파트너십 비용', '${_krw.format(metrics.subscriptionSpendKrw)}원'),
          row('출근 수수료(실제/추정)', '${_krw.format(metrics.commissionSpendKrw)}원'),
          row(
            '기준 수수료(${_krw.format(metrics.baselineCommissionPerCheckInKrw)}원×${metrics.checkIns})',
            '${_krw.format(metrics.baselineCommissionTotalKrw)}원',
          ),
          row('절감액', '${_krw.format(metrics.commissionSavingsVsBasicKrw)}원', bold: true),
          row('총 비용', '${_krw.format(metrics.totalSpendKrw)}원'),
          row('추정 인건비 가치', '${_krw.format(metrics.estimatedLaborValueKrw)}원'),
          pw.SizedBox(height: 12),
          pw.Text(
            'ROI ${metrics.roiPercent.toStringAsFixed(0)}%',
            style: pw.TextStyle(font: fontBold, fontSize: 16),
          ),
          if (branchRows.isNotEmpty) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              '지점별 ROI',
              style: pw.TextStyle(font: fontBold, fontSize: 14),
            ),
            pw.SizedBox(height: 8),
            ...branchRows.map(
              (branch) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      '${branch.levelLabel} · ${branch.branchName}',
                      style: pw.TextStyle(font: fontBold, fontSize: 11),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '지원 ${branch.applications} · 출근 ${branch.checkIns} · '
                      '수수료 ${_krw.format(branch.commissionSpendKrw)}원 · '
                      '절감 ${_krw.format(branch.savingsVsBasicKrw)}원',
                      style: pw.TextStyle(font: font, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            '본 문서는 일자리 앱 ROI 대시보드에서 자동 생성되었습니다. '
            '일자리 알림핀 비용과 출근 확인 수수료(10,000원/건 기준) 절감 효과를 내부 보고용으로 활용하세요.',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
