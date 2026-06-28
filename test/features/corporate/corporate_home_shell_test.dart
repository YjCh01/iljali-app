import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';

import 'package:map/core/session/auth_session.dart';

import 'package:map/core/session/auth_user.dart';

import 'package:map/core/session/member_type.dart';

import 'package:map/core/session/guest_browse_intent.dart';
import 'package:map/features/corporate/presentation/pages/corporate_home_shell_page.dart';

import 'package:map/features/corporate/presentation/widgets/corporate_bottom_nav.dart';

import 'package:map/features/home/presentation/pages/role_based_home_page.dart';

import 'package:map/features/job_seeker/presentation/pages/individual_home_shell_page.dart';

import 'package:shared_preferences/shared_preferences.dart';



Future<void> _tapCorporateNav(WidgetTester tester, int index) async {

  final nav = find.byType(CorporateBottomNav);

  await tester.ensureVisible(nav);

  final icons = find.descendant(of: nav, matching: find.byType(Icon));

  await tester.tap(icons.at(index));

  await tester.pump();

  await tester.pump(const Duration(milliseconds: 300));

}



Future<void> _pumpFrames(WidgetTester tester, {int count = 8}) async {

  for (var i = 0; i < count; i++) {

    await tester.pump(const Duration(milliseconds: 200));

  }

}



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



  testWidgets('corporate guest lands on corporate home shell', (tester) async {
    GuestBrowseIntent.useCorporate();

    await tester.pumpWidget(
      const MaterialApp(home: RoleBasedHomePage()),
    );
    await _pumpFrames(tester, count: 10);

    expect(find.byType(CorporateHomeShellPage), findsOneWidget);
    expect(find.text('둘러보기'), findsOneWidget);
    expect(find.text('로그인'), findsWidgets);
  });

  testWidgets('corporate user lands on corporate home shell', (tester) async {

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

    await _pumpFrames(tester, count: 10);



    expect(find.byType(CorporateHomeShellPage), findsOneWidget);

    expect(find.text('강남물류'), findsOneWidget);

    expect(find.text('채용 현황'), findsOneWidget);
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);

    expect(find.byType(CorporateBottomNav), findsOneWidget);

  });



  testWidgets('individual user lands on job seeker shell', (tester) async {

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

    await _pumpFrames(tester);



    expect(find.byType(IndividualHomeShellPage), findsOneWidget);

    expect(find.text('구직자'), findsOneWidget);

  });



  testWidgets('corporate bottom nav switches job posts tab', (tester) async {

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

    await _pumpFrames(tester, count: 10);



    await _tapCorporateNav(tester, 1);

    await _pumpFrames(tester);



    expect(find.text('등록된 공고가 없습니다'), findsOneWidget);

  });



  testWidgets('corporate tabs 3-6 show empty or upsell states', (tester) async {

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

    await _pumpFrames(tester, count: 10);



    await _tapCorporateNav(tester, 2);

    await _pumpFrames(tester);

    expect(find.text('지원자 연락 이용 제한'), findsOneWidget);



    await _tapCorporateNav(tester, 3);

    await _pumpFrames(tester);



    await _tapCorporateNav(tester, 4);

    await _pumpFrames(tester);

    expect(find.text('지원자 채팅 이용 제한'), findsOneWidget);



    await _tapCorporateNav(tester, 5);

    expect(find.text('내정보 관리'), findsWidgets);

  });



  testWidgets('home stat cards navigate to matching tabs', (tester) async {

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

    await _pumpFrames(tester, count: 10);



    await tester.drag(find.text('채용 현황'), const Offset(0, -360));
    await _pumpFrames(tester, count: 10);

    await tester.tap(find.byKey(const Key('corp-stat-job-posts')));

    await _pumpFrames(tester);

    expect(find.text('등록된 공고가 없습니다'), findsOneWidget);



    await _tapCorporateNav(tester, 0);

    await _pumpFrames(tester);



    await tester.drag(find.text('채용 현황'), const Offset(0, -360));
    await _pumpFrames(tester, count: 10);

    await tester.tap(find.byKey(const Key('corp-stat-unread-chats')));

    await _pumpFrames(tester);

    expect(find.text('지원자 채팅 이용 제한'), findsOneWidget);

  });

}


