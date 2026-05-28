import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_search_bar.dart';

void main() {
  testWidgets('MapSearchBar shows search hint', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MapSearchBar(),
        ),
      ),
    );

    expect(find.text('지역, 일자리, 근무지 검색'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
