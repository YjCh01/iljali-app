import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/home/presentation/pages/role_based_home_page.dart';
import 'package:map/features/job_seeker/presentation/pages/individual_home_shell_page.dart';
import 'package:map/features/job_seeker/presentation/pages/tabs/individual_my_jobs_tab.dart';
import 'package:map/features/job_seeker/presentation/widgets/individual_bottom_nav.dart';

void main() {
  tearDown(() async {
    await AuthSession.instance.signOut();
  });

  testWidgets('guest lands on job seeker shell with map tab enabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RoleBasedHomePage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(IndividualHomeShellPage), findsOneWidget);
    expect(find.text('둘러보기'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
    expect(find.byType(IndividualBottomNav), findsOneWidget);
    expect(find.text('지도'), findsWidgets);
    expect(find.text('내일자리'), findsWidgets);
  });

  testWidgets('guest tapping vault tab shows login prompt', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RoleBasedHomePage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('보관함'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('로그인이 필요합니다'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
  });

  testWidgets('guest can open more tab for login', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: RoleBasedHomePage()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('더보기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('로그인하고 일자리를 지원해 보세요'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
  });

  testWidgets('individual user can switch vault tab', (tester) async {
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

    expect(find.text('나의 보관함'), findsOneWidget);
  });

  test('normalizeSeekerTabIndex maps legacy 6-tab indices', () {
    expect(normalizeSeekerTabIndex(4), 3);
    expect(normalizeSeekerTabIndex(3), 2);
    expect(seekerMyJobsSegmentFromLegacyTab(3), 1);
  });
}
