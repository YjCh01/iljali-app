import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_job_post_speed_dial.dart';
import 'package:map/features/home/presentation/pages/role_based_home_page.dart';

void main() {
  tearDown(() async {
    await AuthSession.instance.signOut();
  });

  testWidgets('job posts tab has no floating speed dial', (tester) async {
    await AuthSession.instance.signIn(
      const AuthUser(
        name: '강남물류',
        email: 'corp@example.com',
        memberType: MemberType.corporate,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: RoleBasedHomePage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    await tester.tap(find.text('공고'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('등록된 공고가 없습니다'), findsOneWidget);
    expect(find.text('공고 등록하기'), findsOneWidget);
    expect(find.byType(CorporateJobPostSpeedDial), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
  });
}
