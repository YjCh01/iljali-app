import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/address/services/workplace_address_mismatch_service.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

void main() {
  test('allows same-address workplace', () {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '1234567890',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '1111',
      businessHeadOfficeAddress: '서울 강남구 테헤란로 1',
    );
    const workplace = WorkplaceAddress(roadAddress: '서울 강남구 테헤란로 1');

    final result = WorkplaceAddressMismatchService.evaluate(
      workplace: workplace,
      profile: profile,
    );
    expect(result.allowed, isTrue);
  });

  test('flags different-address workplace', () {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '1234567890',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '1111',
      businessHeadOfficeAddress: '서울 강남구 테헤란로 1',
    );
    const workplace = WorkplaceAddress(roadAddress: '서울 마포구 월드컵북로 1');

    final result = WorkplaceAddressMismatchService.evaluate(
      workplace: workplace,
      profile: profile,
    );
    expect(result.allowed, isFalse);
    expect(result.requiresAdminReview, isTrue);
  });
}
