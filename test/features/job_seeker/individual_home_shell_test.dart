import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/home/presentation/pages/role_based_home_page.dart';
import 'package:map/features/job_seeker/presentation/pages/individual_home_shell_page.dart';
import 'package:map/features/job_seeker/presentation/widgets/individual_bottom_nav.dart';

void main() {
  tearDown(() async {
    await AuthSession.instance.signOut();
  });

  testWidgets('individual user lands on job seeker shell with map tab', (tester) async {
    await AuthSession.instance.signIn(
      const AuthUser(
        name: '홍길동',
        email: 'user@example.com',
        memberType: MemberType.individual,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: RoleBasedHomePage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(IndividualHomeShellPage), findsOneWidget);
    expect(find.text('구직자'), findsOneWidget);
    expect(find.byType(IndividualBottomNav), findsOneWidget);
    expect(find.text('지도'), findsOneWidget);
  });

  testWidgets('individual bottom nav switches vault tab', (tester) async {
    await AuthSession.instance.signIn(
      const AuthUser(
        name: '홍길동',
        email: 'user@example.com',
        memberType: MemberType.individual,
      ),
    );

    await tester.pumpWidget(
      const MaterialApp(home: RoleBasedHomePage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('보관함'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('보관함'), findsWidgets);
    expect(find.text('공고'), findsNothing);
  });
}
