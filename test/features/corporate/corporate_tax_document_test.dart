import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/business_entity_type.dart';
import 'package:map/features/corporate/data/repositories/corporate_tax_document_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/payment_method.dart';
import 'package:map/features/corporate/domain/entities/payment_product_category.dart';
import 'package:map/features/corporate/domain/entities/tax_document_type.dart';
import 'package:map/features/corporate/domain/services/corporate_tax_document_service.dart';
import 'package:map/features/corporate/domain/services/tax_document_policy.dart';
import 'package:shared_preferences/shared_preferences.dart';

CorporateMemberProfile _profile({BusinessEntityType type = BusinessEntityType.corporation}) {
  return CorporateMemberProfile(
    companyName: '테스트물류',
    businessRegistrationNumber: '123-45-67890',
    department: '인사',
    contactPersonName: '김담당',
    handlerCode: '1001',
    entityType: type,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('card + corporation issues statement and tax invoice', () {
    final types = TaxDocumentPolicy.requiredTypes(
      method: PaymentMethod.card,
      profile: _profile(),
    );
    expect(types, [
      TaxDocumentType.transactionStatement,
      TaxDocumentType.taxInvoice,
    ]);
  });

  test('bank transfer also issues cash receipt', () {
    final types = TaxDocumentPolicy.requiredTypes(
      method: PaymentMethod.bankTransfer,
      profile: _profile(),
    );
    expect(types, contains(TaxDocumentType.cashReceipt));
  });

  test('sole proprietor kakao pay issues cash receipt', () {
    final types = TaxDocumentPolicy.requiredTypes(
      method: PaymentMethod.kakaoPay,
      profile: _profile(type: BusinessEntityType.soleProprietor),
    );
    expect(types, contains(TaxDocumentType.cashReceipt));
  });

  test('recordPayment persists documents by company', () async {
    final service = CorporateTaxDocumentService();
    final profile = _profile();

    final docs = await service.recordPayment(
      context: PaymentRequestContext(
        orderId: 'COMM-TEST-1',
        productName: '채용 수수료 · 홍길동',
        amountKrw: 15000,
        method: PaymentMethod.card,
        category: PaymentProductCategory.hiringCommission,
        transactionId: 'TX-1',
        profile: profile,
        buyerEmail: 'corp@test.com',
      ),
    );

    expect(docs.length, 2);

    final repo = await CorporateTaxDocumentRepository.create();
    final stored = await repo.listForCompany(profile.companyKey);
    expect(stored.length, 2);
    expect(stored.first.orderId, 'COMM-TEST-1');
  });
}
