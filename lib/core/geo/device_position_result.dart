import 'package:map/core/geo/geo_coordinate.dart';

/// GPS 조회 결과 — 좌표 + 모의 위치 여부
class DevicePositionResult {
  const DevicePositionResult({
    required this.coordinate,
    this.isMocked = false,
    this.accuracyMeters,
  });

  final GeoCoordinate coordinate;
  final bool isMocked;
  final double? accuracyMeters;
}
