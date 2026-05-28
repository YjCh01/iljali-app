import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/services/partnership_subscription_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';

void main() {
  group('PartnershipSubscriptionService', () {
    final service = PartnershipSubscriptionService();

    test('switchToBasic clears legacy subscription flags', () async {
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
            subscriptionExpiresAt: DateTime.now().add(const Duration(days: 20)),
          ),
        ),
      );

      final profile = AuthSession.instance.currentUser!.corporateProfile!;
      final result = await service.switchToBasic(
        profile: profile,
        agreedToTerms: true,
      );

      expect(result.success, isTrue);
      final updated = AuthSession.instance.currentUser?.corporateProfile;
      expect(updated?.monthlySubscriptionActive, isFalse);
      expect(updated?.subscriptionExpiresAt, isNull);
      expect(updated?.pushWallet, isNotNull);
    });
  });
}
