import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/address/workplace_address_platform.dart';
import 'package:map/core/address/workplace_address_qc.dart';

void main() {
  test('WorkplaceAddressQc sample has road and coordinate', () {
    final sample = WorkplaceAddressQc.sample();
    expect(sample.roadAddress, isNotEmpty);
    expect(sample.coordinate, isNotNull);
  });

  test('WorkplaceAddressQc fromManualInput trims road address', () {
    final address = WorkplaceAddressQc.fromManualInput(
      roadAddress: '  서울시 강남구 역삼동  ',
    );
    expect(address.roadAddress, '서울시 강남구 역삼동');
    expect(address.coordinate, WorkplaceAddressQc.sampleCoordinate);
  });

  test(
    'WorkplaceAddressPlatform postcode support matches mobile only',
    () {
      final supported = WorkplaceAddressPlatform.isPostcodeWebViewSupported;
      if (kIsWeb) {
        expect(supported, isFalse);
      } else {
        expect(
          supported,
          defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS,
        );
      }
    },
  );
}
