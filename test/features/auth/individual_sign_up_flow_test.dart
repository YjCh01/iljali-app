import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/auth/domain/services/mock_phone_verification_service.dart';
import 'package:map/features/auth/domain/services/phone_verification_service.dart';
import 'package:map/features/auth/presentation/pages/auth/individual_sign_up_flow.dart';

void main() {
  setUp(MockPhoneVerificationService.instance.clear);

  Widget buildFlow() {
    return MaterialApp(
      home: IndividualSignUpFlow(
        phoneVerification: PhoneVerificationService.localMock(),
      ),
    );
  }

  testWidgets('individual signup starts with phone verification step', (tester) async {
    await tester.pumpWidget(buildFlow());

    expect(find.text('휴대폰 본인인증'), findsOneWidget);
    expect(find.text('인증번호 받기'), findsOneWidget);
    expect(find.text('계정 만들기'), findsNothing);
  });

  testWidgets('phone step advances to verification after send code', (tester) async {
    await tester.pumpWidget(buildFlow());

    await tester.enterText(find.byType(TextField).first, '01012345678');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('인증번호 입력'), findsOneWidget);
  });

  testWidgets('verified phone leads to account step only', (tester) async {
    await tester.pumpWidget(buildFlow());

    await tester.enterText(find.byType(TextField).first, '01012345678');
    await tester.tap(find.text('인증번호 받기'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.ensureVisible(find.text('인증 확인'));
    await tester.tap(find.text('인증 확인'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('계정 만들기'), findsWidgets);
    expect(find.text('희망 근무 지역'), findsNothing);
    expect(find.text('실주소 등록'), findsNothing);
  });
}
