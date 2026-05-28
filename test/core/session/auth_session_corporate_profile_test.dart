import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await AuthSession.instance.signOut();
  });

  test('ensureCorporateProfile creates profile for corporate login without profile',
      () async {
    await AuthSession.instance.signIn(
      const AuthUser(
        name: '강남물류',
        email: 'corp@example.com',
        memberType: MemberType.corporate,
      ),
    );

    expect(AuthSession.instance.currentUser?.corporateProfile, isNull);

    final profile = await AuthSession.instance.ensureCorporateProfile();

    expect(profile, isNotNull);
    expect(profile!.companyName, '강남물류');
    expect(profile.handlerCode.length, 4);
    expect(AuthSession.instance.currentUser?.corporateProfile, isNotNull);
  });

  test('ensureCorporateProfile returns null for individual login', () async {
    await AuthSession.instance.signIn(
      const AuthUser(
        name: '홍길동',
        email: 'user@example.com',
        memberType: MemberType.individual,
      ),
    );

    final profile = await AuthSession.instance.ensureCorporateProfile();
    expect(profile, isNull);
  });
}
