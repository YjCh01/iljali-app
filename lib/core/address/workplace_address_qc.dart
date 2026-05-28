import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// 주소 검색 WebView 미지원 환경(Windows 등) QC·로컬 테스트용 근무지
abstract final class WorkplaceAddressQc {
  static const sampleRoadAddress = '서울특별시 강남구 테헤란로 152';
  static const sampleJibunAddress = '서울 강남구 역삼동 737';
  static const sampleDongName = '역삼동';
  static const sampleZipCode = '06236';
  static const sampleCoordinate =
      GeoCoordinate(latitude: 37.5128, longitude: 127.0471);

  static WorkplaceAddress sample({String? detailAddress}) {
    return WorkplaceAddress(
      roadAddress: sampleRoadAddress,
      jibunAddress: sampleJibunAddress,
      dongName: sampleDongName,
      zipCode: sampleZipCode,
      detailAddress: detailAddress,
      coordinate: sampleCoordinate,
    );
  }

  static WorkplaceAddress fromManualInput({
    required String roadAddress,
    String? detailAddress,
  }) {
    final road = roadAddress.trim();
    return WorkplaceAddress(
      roadAddress: road,
      jibunAddress: null,
      dongName: _guessDong(road),
      detailAddress:
          detailAddress == null || detailAddress.trim().isEmpty
              ? null
              : detailAddress.trim(),
      coordinate: sampleCoordinate,
    );
  }

  static String? _guessDong(String road) {
    final match = RegExp(r'(\S+동)').firstMatch(road);
    return match?.group(1);
  }
}
