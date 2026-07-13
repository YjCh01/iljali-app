import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

void main() {
  test('package credits do not change workplace pin tier', () {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '1112223334',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '1111',
      pushWallet: EmployerPushWallet(packageCredits: 1),
    );

    expect(
      MapPinTierResolver.resolveFromProfile(registeredBy: profile),
      JobMapPinDisplayTier.standard,
    );
  });

  test('100-pack buyer without credits stays standard pin tier', () {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '1112223334',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '1111',
      pushWallet: EmployerPushWallet(purchased100PackBundle: true),
    );

    expect(
      MapPinTierResolver.resolveFromProfile(registeredBy: profile),
      JobMapPinDisplayTier.standard,
    );
  });

  test('legacy premiumPartner maps to packageActive', () {
    expect(
      JobMapPinDisplayTierX.tryParseLegacy('premiumPartner'),
      JobMapPinDisplayTier.packageActive,
    );
  });
}
