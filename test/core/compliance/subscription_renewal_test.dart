import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/services/subscription_renewal_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

void main() {
  group('SubscriptionRenewalService', () {
    test('loads wallet without tier downgrade', () async {
      await AuthSession.instance.signIn(
        AuthUser(
          name: '테스트',
          email: 'corp@test.com',
          memberType: MemberType.corporate,
          corporateProfile: CorporateMemberProfile(
            companyName: '테스트',
            businessRegistrationNumber: '1234567890',
            department: '인사',
            contactPersonName: '홍길동',
            handlerCode: '1001',
            partnershipTier: PremiumPartnershipTier.starter,
            monthlySubscriptionActive: true,
            subscriptionExpiresAt:
                DateTime.now().subtract(const Duration(days: 1)),
          ),
        ),
      );

      final result = await SubscriptionRenewalService().checkAndApplyExpiry();
      expect(result.checked, isTrue);
      expect(result.changed, isFalse);

      final profile = AuthSession.instance.currentUser?.corporateProfile;
      expect(profile?.pushWallet, isNotNull);
    });
  });
}
