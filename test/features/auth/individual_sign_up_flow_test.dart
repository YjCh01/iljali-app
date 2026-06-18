import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/auth/domain/services/mock_phone_verification_service.dart';
import 'package:map/features/auth/presentation/pages/auth/individual_sign_up_flow.dart';

void main() {
  setUp(MockPhoneVerificationService.instance.clear);

  testWidgets('individual signup starts with phone verification step', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IndividualSignUpFlow()),
    );

    expect(find.text('휴대폰 번호 인증'), findsOneWidget);
    expect(find.text('인증번호 받기'), findsOneWidget);
    expect(find.text('회원정보'), findsNothing);
  });

  testWidgets('phone step advances to verification after send code', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IndividualSignUpFlow()),
    );

    await tester.enterText(find.byType(TextField).first, '01012345678');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('인증번호 입력'), findsOneWidget);
  });

  testWidgets('verified phone leads to member info before region', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: IndividualSignUpFlow()),
    );

    await tester.enterText(find.byType(TextField).first, '01012345678');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('인증 확인'));
    await tester.pump();

    expect(find.text('생년월일'), findsOneWidget);
    expect(find.text('희망 근무 지역'), findsNothing);
  });
}
