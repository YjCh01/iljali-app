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

  testWidgets('job posts tab shows expandable speed dial', (tester) async {
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

    expect(find.text('공고 등록'), findsNothing);

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('공고 등록'), findsOneWidget);
    expect(find.text('공고 수정'), findsOneWidget);
    expect(find.byType(CorporateJobPostSpeedDial), findsOneWidget);

    final fabCenter = tester.getCenter(find.byIcon(Icons.close_rounded));
    final createCenter = tester.getCenter(find.text('공고 등록'));
    expect(createCenter.dy, lessThan(fabCenter.dy));
    expect(createCenter.dx, closeTo(fabCenter.dx, 72));
  });
}
