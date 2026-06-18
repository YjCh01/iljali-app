import 'package:map/core/geo/geo_coordinate.dart';

/// 셔틀·통근 버스 정류장
class CommuteRouteStop {
  const CommuteRouteStop({
    required this.id,
    required this.label,
    required this.coordinate,
    this.departureTime,
    this.photoPath,
    this.exposureActivated = false,
  });

  final String id;
  final String label;
  final GeoCoordinate coordinate;

  /// 탑승 시간 (예: 07:30). 마지막 정류장은 null → 도착 표시
  final String? departureTime;

  /// 정류장 안내 사진 (로컬 경로)
  final String? photoPath;

  /// 정류장 표시핀 결제·활성화 — 구직자 지도 노출
  final bool exposureActivated;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'coordinate': {
          'latitude': coordinate.latitude,
          'longitude': coordinate.longitude,
        },
        if (departureTime != null) 'departureTime': departureTime,
        if (photoPath != null) 'photoPath': photoPath,
        'exposureActivated': exposureActivated,
      };

  factory CommuteRouteStop.fromJson(Map<String, dynamic> json) {
    final coord = json['coordinate'] as Map<String, dynamic>? ?? {};
    return CommuteRouteStop(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      coordinate: GeoCoordinate(
        latitude: (coord['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (coord['longitude'] as num?)?.toDouble() ?? 0,
      ),
      departureTime: json['departureTime'] as String?,
      photoPath: json['photoPath'] as String?,
      exposureActivated: json['exposureActivated'] as bool? ?? false,
    );
  }

  CommuteRouteStop copyWith({
    String? label,
    GeoCoordinate? coordinate,
    String? departureTime,
    String? photoPath,
    bool? exposureActivated,
    bool clearPhoto = false,
  }) {
    return CommuteRouteStop(
      id: id,
      label: label ?? this.label,
      coordinate: coordinate ?? this.coordinate,
      departureTime: departureTime ?? this.departureTime,
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      exposureActivated: exposureActivated ?? this.exposureActivated,
    );
  }
}
