import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/data/repositories/job_post_payment_request_repository.dart';
import 'package:map/features/corporate/data/repositories/saved_payment_method_repository.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/saved_payment_method.dart';
import 'package:map/features/corporate/domain/services/job_post_payment_request_service.dart';
import 'package:map/features/corporate/domain/services/saved_payment_method_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('saved card register list default remove', () async {
    final service = SavedPaymentMethodService();
    final first = await service.registerMockCard(
      companyKey: '1234567890',
      registeredByEmail: 'a@test.com',
      cardBrand: '신한',
      last4: '1234',
    );
    expect(first.isDefault, isTrue);

    final second = await service.registerMockCard(
      companyKey: '1234567890',
      registeredByEmail: 'a@test.com',
      cardBrand: 'KB국민',
      last4: '5678',
    );
    expect(second.isDefault, isFalse);

    await service.setDefault(companyKey: '1234567890', id: second.id);
    final cards = await service.listForCompany('1234567890');
    expect(cards.first.id, second.id);
    expect(cards.first.isDefault, isTrue);

    await service.removeCard(companyKey: '1234567890', id: first.id);
    final remaining = await service.listForCompany('1234567890');
    expect(remaining.length, 1);
    expect(remaining.first.isDefault, isTrue);
  });

  test('job post payment request create and mark paid', () async {
    const bundle = PushPaymentBundle.pushTicket();
    final request = await JobPostPaymentRequestService().createRequest(
      companyKey: '1234567890',
      requesterEmail: 'recruiter@test.com',
      payerEmail: 'owner@test.com',
      bundle: bundle,
      kind: JobPostPaymentRequestKind.pushTicket,
      jobTitle: '물류센터 야간',
    );
    expect(request.isPending, isTrue);

    final pending = await JobPostPaymentRequestService().listPendingForPayer(
      companyKey: '1234567890',
      payerEmail: 'owner@test.com',
    );
    expect(pending.length, 1);

    final paid = await JobPostPaymentRequestService().markPaid(
      id: request.id,
      transactionId: 'TX-1',
    );
    expect(paid?.status.name, 'paid');

    final after = await JobPostPaymentRequestService().listPendingForPayer(
      companyKey: '1234567890',
      payerEmail: 'owner@test.com',
    );
    expect(after, isEmpty);
  });
}
