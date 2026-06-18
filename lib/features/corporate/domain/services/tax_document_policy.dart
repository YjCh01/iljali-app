import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/tax_document_type.dart';

/// 결제 수단·사업자 유형별 발행 증빙 판정
abstract final class TaxDocumentPolicy {
  static List<TaxDocumentType> requiredTypes({
    required PaymentMethod method,
    CorporateMemberProfile? profile,
  }) {
    final types = <TaxDocumentType>[TaxDocumentType.transactionStatement];

    if (profile != null && _hasBusinessRegistration(profile)) {
      types.add(TaxDocumentType.taxInvoice);
    }

    if (_requiresCashReceipt(method, profile)) {
      types.add(TaxDocumentType.cashReceipt);
    }

    return types;
  }

  static bool _hasBusinessRegistration(CorporateMemberProfile profile) {
    final digits =
        profile.businessRegistrationNumber.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10;
  }

  static bool _requiresCashReceipt(
    PaymentMethod method,
    CorporateMemberProfile? profile,
  ) {
    switch (method) {
      case PaymentMethod.bankTransfer:
        return true;
      case PaymentMethod.kakaoPay:
      case PaymentMethod.naverPay:
      case PaymentMethod.payco:
        return profile?.entityType == BusinessEntityType.soleProprietor;
      case PaymentMethod.card:
      case PaymentMethod.tossPay:
        return false;
    }
  }

  static ({int supplyKrw, int vatKrw}) splitVat(int totalKrw) {
    final vat = (totalKrw / 11).round();
    return (supplyKrw: totalKrw - vat, vatKrw: vat);
  }
}
