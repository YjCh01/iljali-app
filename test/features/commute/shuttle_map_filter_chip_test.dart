import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/commute/presentation/widgets/shuttle_transport_widgets.dart';

void main() {
  group('ShuttleMapFilterChip', () {
    testWidgets('shows 전체 when inactive and 셔틀 있음 when active', (tester) async {
      var active = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                return ShuttleMapFilterChip(
                  active: active,
                  onChanged: (v) => setState(() => active = v),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('전체'), findsOneWidget);
      expect(find.text('셔틀 있음'), findsNothing);
      expect(find.byIcon(Icons.directions_bus_outlined), findsOneWidget);

      await tester.tap(find.byType(ShuttleMapFilterChip));
      await tester.pumpAndSettle();

      expect(find.text('셔틀 있음'), findsOneWidget);
      expect(find.text('전체'), findsNothing);
      expect(find.byIcon(Icons.directions_bus), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });
}
