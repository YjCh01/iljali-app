/// 위·경도 좌표 (지도 SDK 비의존)
class GeoCoordinate {
  const GeoCoordinate({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;

  GeoCoordinate copyWith({
    double? latitude,
    double? longitude,
  }) {
    return GeoCoordinate(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }

  @override
  String toString() => 'GeoCoordinate($latitude, $longitude)';
}
