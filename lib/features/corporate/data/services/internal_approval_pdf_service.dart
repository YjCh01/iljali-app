import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/internal_approval_report.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// 내부 결재 보고서 PDF 생성
class InternalApprovalPdfService {
  const InternalApprovalPdfService();

  static final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');

  Future<Uint8List> buildPdf(InternalApprovalReport report) async {
    final font = await PdfGoogleFonts.notoSansKRRegular();
    final fontBold = await PdfGoogleFonts.notoSansKRBold();
    final profile = report.profile;
    final post = report.post;
    final payment = report.paymentRecord;

    pw.Widget sectionTitle(String text) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 8),
          child: pw.Text(
            text,
            style: pw.TextStyle(font: fontBold, fontSize: 13),
          ),
        );

    pw.Widget row(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 110,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  value,
                  style: pw.TextStyle(font: font, fontSize: 10),
                ),
              ),
            ],
          ),
        );

    final doc = pw.Document(
      title: '내부 결재 보고서',
      author: profile.companyName,
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(
            '공고 등록 · 결제 내부 결재 보고서',
            style: pw.TextStyle(font: fontBold, fontSize: 18),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            '발행: ${_dateFormat.format(DateTime.now())}',
            style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 18),
          sectionTitle('기업 · 담당자'),
          row('회사명', profile.companyName),
          row('사업자등록번호', profile.businessRegistrationNumber),
          row('담당부서', profile.department),
          row('담당자', profile.contactPersonName),
          row('담당자 코드', profile.handlerCode),
          pw.SizedBox(height: 14),
          sectionTitle('공고 등록 정보'),
          row('등록일', _dateFormat.format(post.postedAt)),
          row('공고 제목', post.title),
          row('근무지', post.warehouseName),
          row('시급', post.hourlyWage),
          if (post.dailyWage != null) row('일급', post.dailyWage!),
          row('근무 일정', post.workSchedule),
          row('급여지급일', post.paymentScheduleDisplayLabel ?? '-'),
          row('공고 요약', post.fullDescriptionText),
          if (post.notificationSettings?.primaryBase != null)
            row(
              '푸시 알림',
              post.notificationSettings!.summaryLabel,
            ),
          pw.SizedBox(height: 14),
          sectionTitle('결제 내역'),
          if (payment != null) ...[
            row('주문번호', payment.orderId),
            row('결제 항목', payment.productName),
            row('결제 금액', payment.formattedAmountKrw),
            row('결제 수단', payment.method.label),
            row('승인번호', payment.transactionId),
            row('결제 일시', _dateFormat.format(payment.paidAt)),
          ] else
            pw.Text(
              '유료 결제 항목 없음',
              style: pw.TextStyle(font: font, fontSize: 10),
            ),
          pw.SizedBox(height: 20),
          pw.Text(
            '본 문서는 일자리 앱에서 자동 생성된 내부 결재용 보고서입니다.',
            style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
