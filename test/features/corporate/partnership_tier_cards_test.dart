import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/presentation/widgets/create_job_post/partnership_tier_cards.dart';

void main() {
  testWidgets('shows default plan and package bundles', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);

    var shopTapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: PartnershipTierCards(
              onShopTap: () => shopTapped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text(PushPackageCatalog.defaultPlanLabel), findsOneWidget);
    expect(find.text('10회 팩'), findsOneWidget);
    expect(find.textContaining('45,000원 / 반경1km'), findsOneWidget);
    expect(find.text('30회 팩'), findsOneWidget);
    expect(find.text('100회 팩'), findsOneWidget);
    expect(find.text('공고 노출·모집 패키지 보기'), findsOneWidget);
    expect(find.text('BASIC'), findsNothing);
    expect(find.text('Starter'), findsNothing);

    await tester.tap(find.text('공고 노출·모집 패키지 보기'));
    await tester.pump();

    expect(shopTapped, isTrue);
  });
}
