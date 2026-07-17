import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';
import 'package:map/features/job_seeker/presentation/widgets/individual_bottom_nav.dart';

void main() {
  testWidgets('IndividualBottomNav shows the my-jobs badge count', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: IndividualBottomNav(
            currentIndex: 0,
            onTap: (_) {},
            myJobsBadgeCount: 4,
          ),
        ),
      ),
    );

    expect(find.text('4'), findsOneWidget);
  });

  testWidgets('IndividualBottomNav hides the my-jobs badge when count is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: IndividualBottomNav(
            currentIndex: 0,
            onTap: (_) {},
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byType(IndividualBottomNav),
        matching: find.byType(NavBadgeDot),
      ),
      findsNothing,
    );
  });
}
