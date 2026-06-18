import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_color_utils.dart';

void main() {
  test('hex and rgb round-trip', () {
    const hex = '#E53935';
    final rgb = ShuttleRouteColorUtils.rgbFromHex(hex);
    expect(rgb.r, 229);
    expect(rgb.g, 57);
    expect(rgb.b, 53);
    expect(
      ShuttleRouteColorUtils.hexFromRgb(rgb.r, rgb.g, rgb.b),
      hex,
    );
  });

  test('validates hex input', () {
    expect(ShuttleRouteColorUtils.isValidHex('#FFFFFF'), isTrue);
    expect(ShuttleRouteColorUtils.isValidHex('FFFFFF'), isTrue);
    expect(ShuttleRouteColorUtils.isValidHex('#GGGGGG'), isFalse);
  });
}
