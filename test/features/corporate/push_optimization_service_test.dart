import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/services/push_optimization_service.dart';

void main() {
  group('PushOptimizationService', () {
    test('recommends 700m with extra bases when history is sparse', () async {
      final rec = await PushOptimizationService().recommend(
        companyKey: 'nonexistent_company_key',
      );
      expect(rec.suggestedRadius, PushRadiusTier.standardFree1km);
      expect(rec.suggestedBaseCount, greaterThan(1));
      expect(rec.expectedReach, greaterThan(0));
      expect(rec.headlineLabel, contains('700m'));
      expect(rec.reason, isNot(contains('3km')));
      expect(rec.confidencePercent, inInclusiveRange(0, 100));
    });

    test('send time label formats hour', () async {
      final rec = await PushOptimizationService().recommend(
        companyKey: 'nonexistent_company_key',
      );
      expect(rec.sendTimeLabel, matches(RegExp(r'^\d{2}:00$')));
    });
  });
}
