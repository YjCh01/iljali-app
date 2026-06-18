import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';

/// 통근 버스·셔틀 경로
class CommuteRoute {
  /// 노선당 등록 가능한 정류장 상한 (추가·수정 공통)
  static const maxStopsPerRoute = 15;

  const CommuteRoute({
    required this.id,
    required this.companyKey,
    required this.routeName,
    required this.stops,
    this.polylinePoints = const [],
    this.active = true,
    this.overlayColorHex = '#E53935',
    this.isFreeShuttle = false,
    this.boardingNotes = '',
    this.arrivalInstructions = '',
    this.vehicleGuide = '',
  });

  final String id;
  final String companyKey;
  final String routeName;
  final List<CommuteRouteStop> stops;
  final List<GeoCoordinate> polylinePoints;
  final bool active;
  final String overlayColorHex;

  /// 무료送迎 여부 (구직자 배지)
  final bool isFreeShuttle;

  /// 탑승 방법·정류장 안내
  final String boardingNotes;

  /// 출근·게이트 체크인 등
  final String arrivalInstructions;

  /// 차량 번호판·외관 등 탑승 식별 안내
  final String vehicleGuide;

  List<String> get stopLabels => stops.map((s) => s.label).toList();

  /// 정류장 좌표를 연결한 경로 (polylinePoints 미지정 시)
  List<GeoCoordinate> get effectivePolylinePoints {
    if (polylinePoints.length >= 2) return polylinePoints;
    if (stops.length < 2) return const [];
    return stops.map((s) => s.coordinate).toList();
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'companyKey': companyKey,
        'routeName': routeName,
        'stops': stops.map((s) => s.toJson()).toList(),
        'polylinePoints': polylinePoints
            .map(
              (c) => {
                'latitude': c.latitude,
                'longitude': c.longitude,
              },
            )
            .toList(),
        'active': active,
        'overlayColorHex': overlayColorHex,
        'isFreeShuttle': isFreeShuttle,
        'boardingNotes': boardingNotes,
        'arrivalInstructions': arrivalInstructions,
        'vehicleGuide': vehicleGuide,
      };

  factory CommuteRoute.fromJson(Map<String, dynamic> json) {
    final stops = (json['stops'] as List<dynamic>? ?? const [])
        .map((e) => CommuteRouteStop.fromJson(e as Map<String, dynamic>))
        .toList();
    final legacyLabels = (json['stopLabels'] as List<dynamic>? ?? const [])
        .map((e) => '$e')
        .toList();
    final resolvedStops = stops.isNotEmpty
        ? stops
        : legacyLabels
            .asMap()
            .entries
            .map(
              (e) => CommuteRouteStop(
                id: 'legacy_${e.key}',
                label: e.value,
                coordinate: const GeoCoordinate(latitude: 0, longitude: 0),
              ),
            )
            .toList();

    final polyline = (json['polylinePoints'] as List<dynamic>? ?? const [])
        .map(
          (e) {
            final m = e as Map<String, dynamic>;
            return GeoCoordinate(
              latitude: (m['latitude'] as num).toDouble(),
              longitude: (m['longitude'] as num).toDouble(),
            );
          },
        )
        .toList();

    return CommuteRoute(
      id: json['id'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      routeName: json['routeName'] as String? ?? '',
      stops: resolvedStops,
      polylinePoints: polyline,
      active: json['active'] as bool? ?? true,
      overlayColorHex: json['overlayColorHex'] as String? ?? '#E53935',
      isFreeShuttle: json['isFreeShuttle'] as bool? ?? false,
      boardingNotes: json['boardingNotes'] as String? ?? '',
      arrivalInstructions: json['arrivalInstructions'] as String? ?? '',
      vehicleGuide: json['vehicleGuide'] as String? ?? '',
    );
  }

  CommuteRoute copyWith({
    String? routeName,
    List<CommuteRouteStop>? stops,
    List<GeoCoordinate>? polylinePoints,
    bool? active,
    String? overlayColorHex,
    bool? isFreeShuttle,
    String? boardingNotes,
    String? arrivalInstructions,
    String? vehicleGuide,
  }) {
    return CommuteRoute(
      id: id,
      companyKey: companyKey,
      routeName: routeName ?? this.routeName,
      stops: stops ?? this.stops,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      active: active ?? this.active,
      overlayColorHex: overlayColorHex ?? this.overlayColorHex,
      isFreeShuttle: isFreeShuttle ?? this.isFreeShuttle,
      boardingNotes: boardingNotes ?? this.boardingNotes,
      arrivalInstructions: arrivalInstructions ?? this.arrivalInstructions,
      vehicleGuide: vehicleGuide ?? this.vehicleGuide,
    );
  }
}
