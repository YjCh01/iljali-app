import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

void main() {
  test('coordinatesDifferMeaningfully detects workplace vs gangnam fallback', () {
    const gangnam = GeoCoordinate(latitude: 37.5128, longitude: 127.0471);
    const anseong = GeoCoordinate(latitude: 37.005, longitude: 127.234);

    expect(isLikelyDefaultPushMapCenter(gangnam), isTrue);
    expect(
      coordinatesDifferMeaningfully(gangnam, anseong),
      isTrue,
    );
  });

  test('WorkplaceAddress without coordinate should not reuse gangnam viewport', () {
    const workplace = WorkplaceAddress(roadAddress: '경기 안성시 소동산길 3-29');
    const saved = GeoCoordinate(latitude: 37.5128, longitude: 127.0471);
    final target = defaultPushMapCenter();

    expect(workplace.coordinate, isNull);
    expect(
      coordinatesDifferMeaningfully(saved, target),
      isFalse,
    );
  });
}
