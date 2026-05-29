import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/services/partnership_subscription_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/presentation/pages/corporate_home_shell_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await AuthSession.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('home shows default plan after legacy downgrade', (tester) async {
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
          handlerCode: '1002',
          partnershipTier: PremiumPartnershipTier.starter,
          monthlySubscriptionActive: true,
          subscriptionExpiresAt: DateTime.now().add(const Duration(days: 30)),
        ),
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: CorporateHomeShellPage()),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text(PushPackageCatalog.defaultPlanLabel), findsWidgets);
    expect(find.text('Starter'), findsNothing);

    final profile = AuthSession.instance.currentUser!.corporateProfile!;
    final result = await PartnershipSubscriptionService().switchToBasic(
      profile: profile,
      agreedToTerms: true,
    );
    expect(result.success, isTrue);

    AuthSession.instance.corporateProfileRevision.value++;

    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Starter'), findsNothing);
    expect(find.text(PushPackageCatalog.defaultPlanLabel), findsWidgets);
  });
}
