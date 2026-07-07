import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/job_seeker/domain/policies/seeker_job_actions_policy.dart';

void main() {
  tearDown(() async {
    await AuthSession.instance.signOut();
  });

  test('corporate user cannot perform seeker actions', () async {
    await AuthSession.instance.signIn(
      const AuthUser(
        name: '담당',
        email: 'corp@test.com',
        memberType: MemberType.corporate,
        corporateProfile: CorporateMemberProfile(
          companyName: '테스트',
          businessRegistrationNumber: '1234567890',
          department: 'HR',
          contactPersonName: '담당',
          handlerCode: '1111',
        ),
      ),
    );

    expect(SeekerJobActionsPolicy.isSignedInCorporate, isTrue);
    expect(SeekerJobActionsPolicy.canPerformSeekerActions, isFalse);
    expect(
      SeekerJobActionsPolicy.showSeekerActionUi(employerPreview: false),
      isFalse,
    );
    expect(
      SeekerJobActionsPolicy.showSeekerActionUi(employerPreview: true),
      isFalse,
    );
  });

  test('seeker user can perform actions unless employer preview', () async {
    await AuthSession.instance.signIn(
      const AuthUser(
        name: '구직',
        email: 'seeker@test.com',
        memberType: MemberType.individual,
      ),
    );

    expect(SeekerJobActionsPolicy.canPerformSeekerActions, isTrue);
    expect(
      SeekerJobActionsPolicy.showSeekerActionUi(employerPreview: false),
      isTrue,
    );
    expect(
      SeekerJobActionsPolicy.showSeekerActionUi(employerPreview: true),
      isFalse,
    );
  });
}
