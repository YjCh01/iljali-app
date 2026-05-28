import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/data/datasources/create_job_post_wizard_local_data_source.dart';
import 'package:map/features/corporate/presentation/pages/corporate_create_job_post_page.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/partnership_tier_cards.dart';

void main() {
  testWidgets('create job post wizard follows premium yes flow', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          AppRoutes.corporateCreateJobPost: (_) =>
              const CorporateCreateJobPostPage(),
        },
        initialRoute: AppRoutes.corporateCreateJobPost,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('일자리 프로모션 제휴사이신가요?'), findsOneWidget);

    await tester.tap(find.text('네'));
    await tester.pumpAndSettle();

    expect(find.text('해당 기업을 선택해주세요'), findsOneWidget);
    expect(find.text('다이소'), findsOneWidget);
    expect(find.text('쿠팡풀필먼트서비스'), findsOneWidget);
    expect(find.text('CJ'), findsWidgets);

    await tester.tap(find.text('다이소'));
    await tester.pumpAndSettle();

    expect(
      find.text('이전에 채용하신 조건으로 채용하시겠습니까?'),
      findsOneWidget,
    );

    await tester.tap(find.text('아니오').last);
    await tester.pumpAndSettle();

    expect(
      find.text(CreateJobPostWizardLocalDataSourceImpl.workerTypeQuestion),
      findsOneWidget,
    );
    expect(find.text('일용직'), findsOneWidget);
    expect(find.text('일반'), findsNothing);
    expect(find.text('계약직'), findsNothing);
  });

  testWidgets('create job post wizard shows benefits on premium no', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CorporateCreateJobPostPage()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('아니오'));
    await tester.pumpAndSettle();

    expect(
      find.text('일자리 프로모션 제휴사 가입 시 혜택 사항을 채팅 탭으로 보내드렸습니다.'),
      findsOneWidget,
    );
    expect(find.textContaining('현재 기본 플랜'), findsOneWidget);
    expect(find.text('현재 플랜으로 공고 등록하기'), findsOneWidget);
    expect(find.text('공고 노출·모집 패키지 보기'), findsOneWidget);
    expect(find.text('BASIC'), findsNothing);
    expect(find.text('Starter'), findsNothing);

    await tester.tap(find.text('공고 노출·모집 패키지 보기'));
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

    await tester.tap(find.text('공고 노출·모집 패키지 보기'));
    await tester.pump();

    expect(shopTapped, isTrue);
  });
}
