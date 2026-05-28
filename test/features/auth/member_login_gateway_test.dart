import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/app.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/auth/presentation/pages/auth/login_page.dart';
import 'package:map/features/auth/presentation/pages/auth/member_login_gateway_page.dart';

void main() {
  testWidgets('app starts on member login gateway', (tester) async {
    await tester.pumpWidget(const MapApp());
    await tester.pumpAndSettle();

    expect(find.byType(MemberLoginGatewayPage), findsOneWidget);
    expect(find.text('기업회원 로그인'), findsOneWidget);
    expect(find.text('개인회원 로그인'), findsOneWidget);
  });

  testWidgets('corporate login button opens login page', (tester) async {
    await tester.pumpWidget(const MapApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('기업회원 로그인'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.text('기업회원 로그인'), findsWidgets);

    final route = ModalRoute.of(
      tester.element(find.byType(LoginPage)),
    );
    expect(route?.settings.arguments, MemberType.corporate);
  });

  testWidgets('individual login button opens login page', (tester) async {
    await tester.pumpWidget(const MapApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('개인회원 로그인'));
    await tester.pumpAndSettle();

    expect(find.byType(LoginPage), findsOneWidget);

    final route = ModalRoute.of(
      tester.element(find.byType(LoginPage)),
    );
    expect(route?.settings.arguments, MemberType.individual);
  });
}
