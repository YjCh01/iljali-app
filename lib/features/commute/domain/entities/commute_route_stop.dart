import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_source.dart';

/// 셔틀·통근 버스 정류장
class CommuteRouteStop {
  const CommuteRouteStop({
    required this.id,
    required this.label,
    required this.coordinate,
    this.departureTime,
    this.arrivalTime,
    this.photoPath,
    this.exposureActivated = false,
    this.exposurePaidAt,
    this.exposureActivationSource,
  });

  final String id;
  final String label;
  final GeoCoordinate coordinate;

  /// 경유 정류장 탑승(출발) 시각 — 예: 07:30
  final String? departureTime;

  /// 근무지 도착 시각 — 말단 근무지 전용 (예: 08:30)
  final String? arrivalTime;

  /// 정류장 안내 사진 (로컬 경로)
  final String? photoPath;

  /// 정류장 표시핀 결제·활성화 — 구직자 지도 노출
  final bool exposureActivated;

  /// 노출 활성화 시각 — D+1 23:59:59
  final DateTime? exposurePaidAt;

  /// 활성화 유형 — 프로모션 종료 시 promo만 회수
  final ExposureActivationSource? exposureActivationSource;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'coordinate': {
          'latitude': coordinate.latitude,
          'longitude': coordinate.longitude,
        },
        if (departureTime != null) 'departureTime': departureTime,
        if (arrivalTime != null) 'arrivalTime': arrivalTime,
        if (photoPath != null) 'photoPath': photoPath,
        'exposureActivated': exposureActivated,
        if (exposurePaidAt != null)
          'exposurePaidAt': exposurePaidAt!.toIso8601String(),
        if (exposureActivationSource != null)
          'exposureActivationSource': exposureActivationSource!.storageValue,
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
      arrivalTime: json['arrivalTime'] as String?,
      photoPath: json['photoPath'] as String?,
      exposureActivated: json['exposureActivated'] as bool? ?? false,
      exposurePaidAt: DateTime.tryParse(json['exposurePaidAt'] as String? ?? ''),
      exposureActivationSource: ExposureActivationSourceX.tryParse(
        json['exposureActivationSource'] as String?,
      ),
    );
  }

  CommuteRouteStop copyWith({
    String? label,
    GeoCoordinate? coordinate,
    String? departureTime,
    String? arrivalTime,
    String? photoPath,
    bool? exposureActivated,
    DateTime? exposurePaidAt,
    ExposureActivationSource? exposureActivationSource,
    bool clearPhoto = false,
    bool clearExposurePaidAt = false,
    bool clearExposureActivationSource = false,
    bool clearDepartureTime = false,
    bool clearArrivalTime = false,
  }) {
    return CommuteRouteStop(
      id: id,
      label: label ?? this.label,
      coordinate: coordinate ?? this.coordinate,
      departureTime: clearDepartureTime
          ? null
          : (departureTime ?? this.departureTime),
      arrivalTime:
          clearArrivalTime ? null : (arrivalTime ?? this.arrivalTime),
      photoPath: clearPhoto ? null : (photoPath ?? this.photoPath),
      exposureActivated: exposureActivated ?? this.exposureActivated,
      exposurePaidAt:
          clearExposurePaidAt ? null : exposurePaidAt ?? this.exposurePaidAt,
      exposureActivationSource: clearExposureActivationSource
          ? null
          : exposureActivationSource ?? this.exposureActivationSource,
    );
  }
}
