/// 지도상의 위치를 나타내는 도메인 엔티티
class MapLocation {
  const MapLocation({
    required this.latitude,
    required this.longitude,
    this.label,
  });

  final double latitude;
  final double longitude;
  final String? label;
}
