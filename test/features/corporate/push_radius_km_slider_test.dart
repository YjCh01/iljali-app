import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

void main() {
  testWidgets('PushRadiusKmSlider renders discrete steps without error',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PushRadiusKmSlider(
            selectedKm: 7,
            allowedKmSteps: const [0, 1, 3, 5, 7],
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('7km'), findsWidgets);
  });

  testWidgets('PushRadiusKmSlider snaps unknown km to nearest step',
      (tester) async {
    var selected = 5;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PushRadiusKmSlider(
                selectedKm: selected,
                allowedKmSteps: const [0, 1, 3, 5, 7],
                onChanged: (km) => setState(() => selected = km),
              );
            },
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets('PushRadiusMapPicker shows existing point overlays', (tester) async {
    const center = GeoCoordinate(latitude: 37.5128, longitude: 127.0471);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 320,
            width: 320,
            child: PushRadiusMapPicker(
              center: center,
              radiusMeters: 700,
              existingPoints: const [
                PushRadiusMapOverlayPoint(
                  coordinate: GeoCoordinate(
                    latitude: 37.5168,
                    longitude: 127.0511,
                  ),
                  radiusMeters: 3000,
                  label: '근무지',
                  pointIndex: 0,
                ),
              ],
              activePointLabel: '모집지역 1',
              onCenterChanged: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.textContaining('근무지'), findsWidgets);
    expect(find.text('모집지역 1'), findsOneWidget);
    expect(find.textContaining('37.51280'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });
}
