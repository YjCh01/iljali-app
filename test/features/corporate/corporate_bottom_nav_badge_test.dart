import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_bottom_nav.dart';

void main() {
  Future<void> pumpBadge(WidgetTester tester, int count) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: NavBadgeDot(count: count)),
      ),
    );
  }

  testWidgets('NavBadgeDot renders nothing when count is zero', (
    tester,
  ) async {
    await pumpBadge(tester, 0);
    expect(find.byType(NavBadgeDot), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('NavBadgeDot shows the count when positive', (tester) async {
    await pumpBadge(tester, 3);
    expect(find.text('3'), findsOneWidget);
  });

  testWidgets('NavBadgeDot caps display at 99+', (tester) async {
    await pumpBadge(tester, 150);
    expect(find.text('99+'), findsOneWidget);
  });

  testWidgets('CorporateBottomNav shows the applicants badge count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: CorporateBottomNav(
            currentIndex: 0,
            onTap: (_) {},
            applicantsBadgeCount: 5,
          ),
        ),
      ),
    );

    expect(find.text('5'), findsOneWidget);
  });

  testWidgets(
    'CorporateBottomNav hides the applicants badge when count is zero',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CorporateBottomNav(
              currentIndex: 0,
              onTap: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.descendant(
          of: find.byType(CorporateBottomNav),
          matching: find.byType(NavBadgeDot),
        ),
        findsNothing,
      );
    },
  );
}
