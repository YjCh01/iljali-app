import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/dev/qc_demo_addresses.dart';

void main() {
  test('detects legacy QC dongtan address variants', () {
    expect(
      QcDemoAddresses.isLegacyDemo('경기도 화성시 동탄대로 123'),
      isTrue,
    );
    expect(
      QcDemoAddresses.isLegacyDemo('경기 화성시 동탄대로 123'),
      isTrue,
    );
    expect(
      QcDemoAddresses.isLegacyDemo('경기 안성시 소동산길 3-29'),
      isFalse,
    );
  });
}
