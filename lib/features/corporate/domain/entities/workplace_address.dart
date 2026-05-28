import 'package:map/core/geo/geo_coordinate.dart';

/// 근무지 주소 (동·도로명 검색 결과)
class WorkplaceAddress {
  const WorkplaceAddress({
    required this.roadAddress,
    this.jibunAddress,
    this.dongName,
    this.buildingName,
    this.zipCode,
    this.detailAddress,
    this.coordinate,
  });

  final String roadAddress;
  final String? jibunAddress;
  final String? dongName;
  final String? buildingName;
  final String? zipCode;
  final String? detailAddress;
  final GeoCoordinate? coordinate;

  String get displayLabel {
    if (detailAddress != null && detailAddress!.isNotEmpty) {
      return '$roadAddress $detailAddress';
    }
    return roadAddress;
  }

  String get shortLabel => dongName ?? roadAddress;

  WorkplaceAddress copyWith({
    String? roadAddress,
    String? jibunAddress,
    String? dongName,
    String? buildingName,
    String? zipCode,
    String? detailAddress,
    GeoCoordinate? coordinate,
  }) {
    return WorkplaceAddress(
      roadAddress: roadAddress ?? this.roadAddress,
      jibunAddress: jibunAddress ?? this.jibunAddress,
      dongName: dongName ?? this.dongName,
      buildingName: buildingName ?? this.buildingName,
      zipCode: zipCode ?? this.zipCode,
      detailAddress: detailAddress ?? this.detailAddress,
      coordinate: coordinate ?? this.coordinate,
    );
  }
}
