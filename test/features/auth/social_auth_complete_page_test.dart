import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/auth/presentation/pages/auth/social_auth_complete_page.dart';

/// 네이티브 소셜 로그인 콜백 처리 — initialParams로 직접 전달된 경우
/// (웹뷰 인터셉트 경로) Uri.base 없이도 정상 동작해야 한다.
void main() {
  testWidgets(
    'shows a specific error message when initialParams carries an error',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SocialAuthCompletePage(
            initialParams: {'status': 'error', 'error': 'missing_code', 'provider': 'kakao'},
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('취소되었거나 중단'), findsOneWidget);
    },
  );

  testWidgets(
    'shows a fallback message when no params are available on native',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: SocialAuthCompletePage(),
        ),
      );
      await tester.pump();

      expect(find.textContaining('콜백 정보를 찾을 수 없습니다'), findsOneWidget);
    },
  );

}
