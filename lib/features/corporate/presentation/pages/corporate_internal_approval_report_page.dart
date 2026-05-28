import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/services/internal_approval_pdf_service.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/internal_approval_report.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

/// 공고 결제 후 내부 결재라인 보고서 — PDF 저장·인쇄·공유
class CorporateInternalApprovalReportPage extends StatefulWidget {
  const CorporateInternalApprovalReportPage({
    super.key,
    required this.report,
    this.pdfService = const InternalApprovalPdfService(),
  });

  final InternalApprovalReport report;
  final InternalApprovalPdfService pdfService;

  @override
  State<CorporateInternalApprovalReportPage> createState() =>
      _CorporateInternalApprovalReportPageState();
}

class _CorporateInternalApprovalReportPageState
    extends State<CorporateInternalApprovalReportPage> {
  static final _dateFormat = DateFormat('yyyy.MM.dd HH:mm');

  Uint8List? _pdfBytes;
  bool _loadingPdf = true;
  bool _pdfError = false;
  String? _lastSavedPath;

  @override
  void initState() {
    super.initState();
    _preparePdf();
  }

  Future<void> _preparePdf() async {
    try {
      final bytes = await widget.pdfService.buildPdf(widget.report);
      if (!mounted) return;
      setState(() {
        _pdfBytes = bytes;
        _loadingPdf = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loadingPdf = false;
        _pdfError = true;
      });
    }
  }

  String get _fileName {
    final code = widget.report.profile.handlerCode;
    final stamp = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
    return 'iljari_approval_${code}_$stamp.pdf';
  }

  Future<void> _savePdf() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;

    try {
      Directory dir;
      if (Platform.isAndroid || Platform.isIOS) {
        dir = await getApplicationDocumentsDirectory();
      } else {
        dir = await getDownloadsDirectory() ?? await getApplicationDocumentsDirectory();
      }
      final file = File('${dir.path}${Platform.pathSeparator}$_fileName');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      setState(() => _lastSavedPath = file.path);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF 저장 완료: ${file.path}')),
      );
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF 저장에 실패했습니다.')),
      );
    }
  }

  Future<void> _printPdf() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  Future<void> _sharePdf() async {
    final bytes = _pdfBytes;
    if (bytes == null) return;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _savePdf();
      final path = _lastSavedPath;
      if (path != null) {
        await Share.shareXFiles([XFile(path)], text: '일자리 내부 결재 보고서');
      }
      return;
    }

    await Printing.sharePdf(bytes: bytes, filename: _fileName);
  }

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final profile = report.profile;
    final post = report.post;
    final payment = report.paymentRecord;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('내부 결재 보고서'),
      ),
      body: _loadingPdf
          ? const Center(child: CircularProgressIndicator())
          : _pdfError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'PDF를 만들지 못했습니다.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _loadingPdf = true;
                              _pdfError = false;
                            });
                            _preparePdf();
                          },
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.searchBarBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '결재 제출용 요약',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _SummaryRow('회사', profile.companyName),
                      _SummaryRow('담당자', '${profile.department} · ${profile.contactPersonName}'),
                      _SummaryRow('담당자 코드', profile.handlerCode),
                      const Divider(height: 24),
                      _SummaryRow('공고 등록일', _dateFormat.format(post.postedAt)),
                      _SummaryRow('공고 제목', post.title),
                      _SummaryRow('근무지', post.warehouseName),
                      _SummaryRow('시급 / 일정', '${post.hourlyWage} · ${post.workSchedule}'),
                      if (payment != null) ...[
                        const Divider(height: 24),
                        _SummaryRow('결제 항목', payment.productName),
                        _SummaryRow('결제 금액', payment.formattedAmountKrw),
                        _SummaryRow('결제 수단', payment.method.label),
                        _SummaryRow('승인번호', payment.transactionId),
                        _SummaryRow('결제 일시', _dateFormat.format(payment.paidAt)),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _ActionButton(
                  icon: Icons.save_alt_rounded,
                  label: 'PDF 저장',
                  onPressed: _pdfBytes == null ? null : _savePdf,
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.print_rounded,
                  label: '인쇄',
                  onPressed: _pdfBytes == null ? null : _printPdf,
                ),
                const SizedBox(height: 10),
                _ActionButton(
                  icon: Icons.ios_share_rounded,
                  label: '외부 공유',
                  onPressed: _pdfBytes == null ? null : _sharePdf,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '확인',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: AppColors.primary),
      label: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        side: const BorderSide(color: AppColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
