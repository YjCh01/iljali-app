import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_floating_insets.dart';

void main() {
  group('MapFloatingInsets.pinCalloutBottomInset', () {
    test('anchors above sheet fraction with gap', () {
      expect(
        MapFloatingInsets.pinCalloutBottomInset(
          screenHeight: 800,
          sheetFraction: 0.18,
          gapAboveSheet: 8,
        ),
        800 * 0.18 + 8,
      );
    });

    test('clamps extreme sheet fractions', () {
      expect(
        MapFloatingInsets.pinCalloutBottomInset(
          screenHeight: 800,
          sheetFraction: 0.01,
        ),
        800 * 0.12 + 8,
      );
      expect(
        MapFloatingInsets.pinCalloutBottomInset(
          screenHeight: 800,
          sheetFraction: 0.99,
        ),
        800 * 0.85 + 8,
      );
    });

    test('calloutPinScreenY places pin below geometric center', () {
      expect(MapFloatingInsets.calloutPinScreenY, greaterThan(0.5));
      expect(MapFloatingInsets.calloutPinScreenY, lessThan(0.8));
    });
  });
}
