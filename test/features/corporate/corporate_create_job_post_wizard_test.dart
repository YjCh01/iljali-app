import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/corporate/domain/entities/job_post_write_draft.dart';
import 'package:map/features/corporate/presentation/pages/corporate_job_post_write_page.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/partnership_tier_cards.dart';

void main() {
  testWidgets('create job post route opens write page directly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: SizedBox.shrink()),
        routes: {
          AppRoutes.corporateCreateJobPost: (_) => CorporateJobPostWritePage(
                draft: JobPostWriteDraft(
                  workerCategory: ProductFeatureFlags.defaultWorkerCategory,
                ),
              ),
        },
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pushNamed(AppRoutes.corporateCreateJobPost);
    await tester.pumpAndSettle();

    expect(find.text('일자리 내용 작성'), findsOneWidget);
    expect(find.text('직접 입력으로 등록'), findsNothing);
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

    await tester.tap(find.text('일자리 알림핀 보기'));
    await tester.pump();

    expect(shopTapped, isTrue);
  });
}
