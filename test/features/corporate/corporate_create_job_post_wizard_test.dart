import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/presentation/pages/corporate_create_job_post_page.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/partnership_tier_cards.dart';

void main() {
  testWidgets('create job post opens plan intro without partnership question',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CorporateCreateJobPostPage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('일자리 프로모션 제휴사이신가요?'), findsNothing);
    expect(find.text('네'), findsNothing);
    expect(find.text('아니오'), findsNothing);
    expect(
      find.textContaining('공고 등록은 완전 무료입니다. 등록 후 근무지 1km 무료 푸시'),
      findsOneWidget,
    );
    expect(
      find.textContaining('추가 모집지역은 지역 푸시권으로 설정하거나 모집하기 발송 시 사용됩니다.'),
      findsOneWidget,
    );
    expect(find.textContaining('현재 기본 플랜'), findsOneWidget);
    expect(find.text('공고 등록하기'), findsOneWidget);
    expect(find.text('지역 푸시권 보기'), findsOneWidget);
  });

  testWidgets('create job post shows package options when expanded',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CorporateCreateJobPostPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('지역 푸시권 보기'));
    await tester.pumpAndSettle();

    expect(find.text('10회 팩'), findsOneWidget);
  });

  testWidgets('comparisonOnly shows package shop button', (tester) async {
    var shopTapped = false;
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: PartnershipTierCards(
              comparisonOnly: true,
              onShopTap: () => shopTapped = true,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('지역 푸시권 보기'));
    await tester.pump();

    expect(shopTapped, isTrue);
  });
}
