import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_product_category.dart';
import 'package:map/features/corporate/domain/entities/tax_document_type.dart';

/// 결제 완료 후 발행되는 거래명세서·세금계산서·현금영수증
class CorporateTaxDocument {
  const CorporateTaxDocument({
    required this.id,
    required this.companyKey,
    required this.type,
    required this.category,
    required this.issueNumber,
    required this.orderId,
    required this.transactionId,
    required this.productName,
    required this.totalKrw,
    required this.supplyKrw,
    required this.vatKrw,
    required this.paymentMethod,
    required this.paidAt,
    required this.issuedAt,
    required this.buyerCompanyName,
    required this.buyerRegistrationNumber,
    required this.buyerContactName,
    required this.buyerEmail,
    this.buyerAddress,
    this.referenceId,
    this.statusLabel = '발행완료',
    this.nationalIssuanceId,
  });

  final String id;
  final String companyKey;
  final TaxDocumentType type;
  final PaymentProductCategory category;
  final String issueNumber;
  final String orderId;
  final String transactionId;
  final String productName;
  final int totalKrw;
  final int supplyKrw;
  final int vatKrw;
  final PaymentMethod paymentMethod;
  final DateTime paidAt;
  final DateTime issuedAt;
  final String buyerCompanyName;
  final String buyerRegistrationNumber;
  final String buyerContactName;
  final String buyerEmail;
  final String? buyerAddress;
  final String? referenceId;
  final String statusLabel;
  final String? nationalIssuanceId;

  String get typeLabel => type.label;

  String get categoryLabel => category.label;

  String get paymentMethodLabel => paymentMethod.label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyKey': companyKey,
        'type': type.name,
        'category': category.name,
        'issueNumber': issueNumber,
        'orderId': orderId,
        'transactionId': transactionId,
        'productName': productName,
        'totalKrw': totalKrw,
        'supplyKrw': supplyKrw,
        'vatKrw': vatKrw,
        'paymentMethod': paymentMethod.name,
        'paidAt': paidAt.toIso8601String(),
        'issuedAt': issuedAt.toIso8601String(),
        'buyerCompanyName': buyerCompanyName,
        'buyerRegistrationNumber': buyerRegistrationNumber,
        'buyerContactName': buyerContactName,
        'buyerEmail': buyerEmail,
        if (buyerAddress != null) 'buyerAddress': buyerAddress,
        if (referenceId != null) 'referenceId': referenceId,
        'statusLabel': statusLabel,
        if (nationalIssuanceId != null) 'nationalIssuanceId': nationalIssuanceId,
      };

  factory CorporateTaxDocument.fromJson(Map<String, dynamic> json) {
    return CorporateTaxDocument(
      id: json['id'] as String,
      companyKey: json['companyKey'] as String,
      type: TaxDocumentType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TaxDocumentType.transactionStatement,
      ),
      category: PaymentProductCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => PaymentProductCategory.hiringCommission,
      ),
      issueNumber: json['issueNumber'] as String,
      orderId: json['orderId'] as String,
      transactionId: json['transactionId'] as String,
      productName: json['productName'] as String,
      totalKrw: json['totalKrw'] as int,
      supplyKrw: json['supplyKrw'] as int,
      vatKrw: json['vatKrw'] as int,
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == json['paymentMethod'],
        orElse: () => PaymentMethod.card,
      ),
      paidAt: DateTime.parse(json['paidAt'] as String),
      issuedAt: DateTime.parse(json['issuedAt'] as String),
      buyerCompanyName: json['buyerCompanyName'] as String,
      buyerRegistrationNumber: json['buyerRegistrationNumber'] as String,
      buyerContactName: json['buyerContactName'] as String,
      buyerEmail: json['buyerEmail'] as String,
      buyerAddress: json['buyerAddress'] as String?,
      referenceId: json['referenceId'] as String?,
      statusLabel: json['statusLabel'] as String? ?? '발행완료',
      nationalIssuanceId: json['nationalIssuanceId'] as String?,
    );
  }
}
