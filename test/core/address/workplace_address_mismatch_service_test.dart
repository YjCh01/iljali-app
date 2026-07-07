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
    expect(result.notifyAdmin, isFalse);
  });

  test('different-address workplace posts live and notifies admin', () {
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
    expect(result.allowed, isTrue);
    expect(result.notifyAdmin, isTrue);
  });

  test('missing head office still allows post and notifies admin', () {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '1234567890',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '1111',
    );
    const workplace = WorkplaceAddress(roadAddress: '경기 안성시 대덕면 소동산길 3-29');

    final result = WorkplaceAddressMismatchService.evaluate(
      workplace: workplace,
      profile: profile,
    );
    expect(result.allowed, isTrue);
    expect(result.notifyAdmin, isTrue);
  });
}
