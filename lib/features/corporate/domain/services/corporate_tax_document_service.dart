import 'package:map/features/corporate/data/repositories/corporate_tax_document_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/corporate_tax_document.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_product_category.dart';
import 'package:map/features/corporate/domain/entities/tax_document_type.dart';
import 'package:map/features/corporate/domain/services/tax_document_policy.dart';

/// 공급자(일자리) 고정 정보 — 실 PG·국세청 연동 전 MVP
abstract final class TaxDocumentSupplier {
  static const companyName = '(주)일자리';
  static const registrationNumber = '123-45-67890';
  static const representative = '대표이사';
  static const address = '서울특별시 (MVP)';
  static const businessType = '정보통신업';
  static const businessItem = '구인구직 플랫폼';
}

/// 결제 완료 시 증빙 자동 발행
class CorporateTaxDocumentService {
  CorporateTaxDocumentService({CorporateTaxDocumentRepository? repository})
      : _repository = repository;

  CorporateTaxDocumentRepository? _repository;

  Future<CorporateTaxDocumentRepository> _repo() async =>
      _repository ??= await CorporateTaxDocumentRepository.create();

  Future<List<CorporateTaxDocument>> recordPayment({
    required PaymentRequestContext context,
  }) async {
    final profile = context.profile;
    if (profile == null) return [];

    final types = TaxDocumentPolicy.requiredTypes(
      method: context.method,
      profile: profile,
    );
    final vat = TaxDocumentPolicy.splitVat(context.amountKrw);
    final paidAt = context.paidAt ?? DateTime.now();
    final issuedAt = DateTime.now();
    final txn = context.transactionId ?? context.orderId;

    final docs = types.map((type) {
      final status = _statusFor(type);
      final nationalId = _nationalIdFor(type, txn);
      return CorporateTaxDocument(
        id: '${context.orderId}_${type.name}',
        companyKey: profile.companyKey,
        type: type,
        category: context.category,
        issueNumber: _issueNumber(type, issuedAt, context.orderId),
        orderId: context.orderId,
        transactionId: txn,
        productName: context.productName,
        totalKrw: context.amountKrw,
        supplyKrw: vat.supplyKrw,
        vatKrw: vat.vatKrw,
        paymentMethod: context.method,
        paidAt: paidAt,
        issuedAt: issuedAt,
        buyerCompanyName: profile.companyName,
        buyerRegistrationNumber: profile.businessRegistrationNumber,
        buyerContactName: profile.contactPersonName,
        buyerEmail: context.buyerEmail ?? '',
        buyerAddress: profile.businessHeadOfficeAddress,
        referenceId: context.referenceId,
        statusLabel: status,
        nationalIssuanceId: nationalId,
      );
    }).toList();

    final repo = await _repo();
    await repo.saveAll(docs);
    return docs;
  }

  String _issueNumber(
    TaxDocumentType type,
    DateTime issuedAt,
    String orderId,
  ) {
    final date =
        '${issuedAt.year}${issuedAt.month.toString().padLeft(2, '0')}${issuedAt.day.toString().padLeft(2, '0')}';
    final suffix = orderId.length > 6 ? orderId.substring(orderId.length - 6) : orderId;
    final prefix = switch (type) {
      TaxDocumentType.transactionStatement => 'TS',
      TaxDocumentType.taxInvoice => 'TI',
      TaxDocumentType.cashReceipt => 'CR',
    };
    return '$prefix-$date-$suffix';
  }

  String _statusFor(TaxDocumentType type) => switch (type) {
        TaxDocumentType.transactionStatement => '발행완료',
        TaxDocumentType.taxInvoice => '전자세금계산서 발행 (국세청 전송 대기)',
        TaxDocumentType.cashReceipt => '현금영수증 발행 (국세청 등록)',
      };

  String? _nationalIdFor(TaxDocumentType type, String transactionId) {
    return switch (type) {
      TaxDocumentType.transactionStatement => null,
      TaxDocumentType.taxInvoice => 'NTS-TI-${transactionId.hashCode.abs()}',
      TaxDocumentType.cashReceipt => 'NTS-CR-${transactionId.hashCode.abs()}',
    };
  }

  static String formatKrw(int value) =>
      value.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );

  static String formatPlainText(CorporateTaxDocument doc) {
    final buffer = StringBuffer()
      ..writeln('${doc.typeLabel} (${doc.issueNumber})')
      ..writeln('상태: ${doc.statusLabel}')
      ..writeln('결제일: ${doc.paidAt.toIso8601String().substring(0, 16)}')
      ..writeln('')
      ..writeln('[공급자]')
      ..writeln(TaxDocumentSupplier.companyName)
      ..writeln('사업자등록번호 ${TaxDocumentSupplier.registrationNumber}')
      ..writeln(TaxDocumentSupplier.address)
      ..writeln('')
      ..writeln('[공급받는자]')
      ..writeln(doc.buyerCompanyName)
      ..writeln('사업자등록번호 ${doc.buyerRegistrationNumber}')
      ..writeln('담당 ${doc.buyerContactName}');
    if (doc.buyerAddress != null) {
      buffer.writeln(doc.buyerAddress);
    }
    buffer
      ..writeln('')
      ..writeln('[거래내역]')
      ..writeln('품목: ${doc.productName}')
      ..writeln('구분: ${doc.categoryLabel}')
      ..writeln('결제수단: ${doc.paymentMethodLabel}')
      ..writeln('공급가액: ${formatKrw(doc.supplyKrw)}원')
      ..writeln('부가세: ${formatKrw(doc.vatKrw)}원')
      ..writeln('합계: ${formatKrw(doc.totalKrw)}원')
      ..writeln('주문번호: ${doc.orderId}')
      ..writeln('거래번호: ${doc.transactionId}');
    if (doc.nationalIssuanceId != null) {
      buffer.writeln('국세청 참조: ${doc.nationalIssuanceId}');
    }
    return buffer.toString();
  }
}

class PaymentRequestContext {
  const PaymentRequestContext({
    required this.orderId,
    required this.productName,
    required this.amountKrw,
    required this.method,
    required this.category,
    this.transactionId,
    this.profile,
    this.buyerEmail,
    this.referenceId,
    this.paidAt,
  });

  final String orderId;
  final String productName;
  final int amountKrw;
  final PaymentMethod method;
  final PaymentProductCategory category;
  final String? transactionId;
  final CorporateMemberProfile? profile;
  final String? buyerEmail;
  final String? referenceId;
  final DateTime? paidAt;
}
