/// 지도 화면에 해당하는 위·경도 범위
class MapViewportBounds {
  const MapViewportBounds({
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final double north;
  final double south;
  final double east;
  final double west;

  factory MapViewportBounds.fromCenter({
    required double centerLat,
    required double centerLng,
    required double latSpan,
    required double lngSpan,
  }) {
    return MapViewportBounds(
      north: centerLat + latSpan / 2,
      south: centerLat - latSpan / 2,
      east: centerLng + lngSpan / 2,
      west: centerLng - lngSpan / 2,
    );
  }

  bool contains({
    required double latitude,
    required double longitude,
  }) {
    return latitude >= south &&
        latitude <= north &&
        longitude >= west &&
        longitude <= east;
  }
}
