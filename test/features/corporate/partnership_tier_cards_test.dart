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

    expect(find.text('1회'), findsOneWidget);
    expect(find.text('10회 팩'), findsOneWidget);
    expect(find.text('100회 팩'), findsOneWidget);
    expect(find.text('30회 팩'), findsNothing);
    expect(find.text('일자리 알림핀 보기'), findsOneWidget);
    expect(find.text('BASIC'), findsNothing);
    expect(find.text('Starter'), findsNothing);

    await tester.tap(find.text('일자리 알림핀 보기'));
    await tester.pump();

    expect(shopTapped, isTrue);
  });
}
