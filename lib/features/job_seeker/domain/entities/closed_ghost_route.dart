import 'package:map/core/geo/geo_coordinate.dart';

/// 어드민이 배치한 종료된 셔틀 노선 (유령노선도)
class ClosedGhostRoute {
  const ClosedGhostRoute({
    required this.id,
    required this.workplaceLatitude,
    required this.workplaceLongitude,
    this.label = '',
    this.stops = const [],
    this.ghostPinId,
    this.createdAt,
  });

  final String id;
  final String label;
  final double workplaceLatitude;
  final double workplaceLongitude;
  final List<GeoCoordinate> stops;
  final String? ghostPinId;
  final DateTime? createdAt;

  /// 승차 시작 → 근무지 순 경로
  List<GeoCoordinate> get travelPath => [
        ...stops,
        GeoCoordinate(
          latitude: workplaceLatitude,
          longitude: workplaceLongitude,
        ),
      ];

  factory ClosedGhostRoute.fromJson(Map<String, dynamic> json) {
    final rawStops = json['stops'] as List<dynamic>? ?? [];
    final stops = <GeoCoordinate>[];
    for (final item in rawStops) {
      if (item is! Map) continue;
      final lat = (item['latitude'] as num?)?.toDouble();
      final lng = (item['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      stops.add(GeoCoordinate(latitude: lat, longitude: lng));
    }
    return ClosedGhostRoute(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      workplaceLatitude: (json['workplace_latitude'] as num?)?.toDouble() ?? 0,
      workplaceLongitude:
          (json['workplace_longitude'] as num?)?.toDouble() ?? 0,
      stops: stops,
      ghostPinId: json['ghost_pin_id'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'workplace_latitude': workplaceLatitude,
        'workplace_longitude': workplaceLongitude,
        'stops': [
          for (final s in stops)
            {'latitude': s.latitude, 'longitude': s.longitude},
        ],
        if (ghostPinId != null) 'ghost_pin_id': ghostPinId,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
