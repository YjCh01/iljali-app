import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/presentation/widgets/business_head_office_registration_flow.dart';

void main() {
  test('profileNeedsHeadOffice detects empty head office', () {
    expect(
      BusinessHeadOfficeRegistrationFlow.profileNeedsHeadOffice(null),
      isFalse,
    );
    expect(
      BusinessHeadOfficeRegistrationFlow.profileNeedsHeadOffice(
        const CorporateMemberProfile(
          companyName: '테스트',
          businessRegistrationNumber: '1234567890',
          department: '인사',
          contactPersonName: '홍길동',
          handlerCode: '1001',
        ),
      ),
      isTrue,
    );
  });

  test('shouldOfferInlineRegistration matches head office messages', () {
    expect(
      BusinessHeadOfficeRegistrationFlow.shouldOfferInlineRegistration(
        '사업자 본사 주소를 먼저 등록해야 공고를 올릴 수 있습니다.',
      ),
      isTrue,
    );
    expect(
      BusinessHeadOfficeRegistrationFlow.shouldOfferInlineRegistration(
        '사업장 소재지를 찾지 못했습니다.',
      ),
      isTrue,
    );
  });
}
