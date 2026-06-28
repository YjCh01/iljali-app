import 'package:flutter/material.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/web/push_radius_web_overlay_builder.dart';
import 'package:map/features/corporate/presentation/widgets/push_credit_visual_theme.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PushRadiusWebOverlayBuilder emits active circle and polyline', () {
    const center = GeoCoordinate(latitude: 37.5, longitude: 127.0);
    final built = PushRadiusWebOverlayBuilder.build(
      center: center,
      radiusMeters: 700,
      existingPoints: const [],
      activeTheme: PushCreditVisualTheme.basic,
      routePolylines: const [
        PushRadiusMapPolyline(
          points: [
            GeoCoordinate(latitude: 37.5, longitude: 127.0),
            GeoCoordinate(latitude: 37.51, longitude: 127.01),
          ],
          color: Color(0xFF7C5CFC),
        ),
      ],
    );

    expect(built.circles, hasLength(1));
    expect(built.circles.first.radiusMeters, 700);
    expect(built.polylines, hasLength(1));
    expect(built.markers.any((m) => m.id == 'push_active_center'), isTrue);
  });
}
