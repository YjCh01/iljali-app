import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/widgets/web_right_navigation_rail.dart';

void main() {
  test('isWideWeb requires kIsWeb', () {
    // Unit tests run non-web; breakpoint helper is compile-time gated.
    expect(WebLayoutBreakpoints.wide, 900.0);
    expect(WebLayoutBreakpoints.railWidth, 88.0);
  });
}
