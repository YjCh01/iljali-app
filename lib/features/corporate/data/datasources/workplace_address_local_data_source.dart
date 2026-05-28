import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// 근무지 주소 검색 데이터 소스
abstract class WorkplaceAddressDataSource {
  Future<WorkplaceAddressSearchResult> search(String query);
}

class WorkplaceAddressSearchResult {
  const WorkplaceAddressSearchResult({
    required this.addresses,
    this.mock = false,
    this.message,
  });

  final List<WorkplaceAddress> addresses;
  final bool mock;
  final String? message;
}

/// 오프라인·API 미연동 시 제한 샘플
class WorkplaceAddressLocalDataSource implements WorkplaceAddressDataSource {
  const WorkplaceAddressLocalDataSource();

  static const _addresses = [
    WorkplaceAddress(
      roadAddress: '서울특별시 강남구 테헤란로 152',
      jibunAddress: '서울특별시 강남구 역삼동 737',
      dongName: '역삼동',
      coordinate: GeoCoordinate(latitude: 37.5001, longitude: 127.0364),
    ),
    WorkplaceAddress(
      roadAddress: '서울특별시 강남구 역삼로 180',
      jibunAddress: '서울특별시 강남구 역삼동 823-24',
      dongName: '역삼동',
      coordinate: GeoCoordinate(latitude: 37.5012, longitude: 127.0398),
    ),
    WorkplaceAddress(
      roadAddress: '서울특별시 강남구 선릉로 514',
      jibunAddress: '서울특별시 강남구 삼성동 168-1',
      dongName: '삼성동',
      coordinate: GeoCoordinate(latitude: 37.5045, longitude: 127.0489),
    ),
    WorkplaceAddress(
      roadAddress: '서울특별시 강남구 강남대로 396',
      jibunAddress: '서울특별시 강남구 역삼동 825',
      dongName: '역삼동',
      coordinate: GeoCoordinate(latitude: 37.4979, longitude: 127.0276),
    ),
    WorkplaceAddress(
      roadAddress: '서울특별시 송파구 올림픽로 300',
      jibunAddress: '서울특별시 송파구 신천동 29',
      dongName: '신천동',
      coordinate: GeoCoordinate(latitude: 37.5133, longitude: 127.1002),
    ),
  ];

  @override
  Future<WorkplaceAddressSearchResult> search(String query) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const WorkplaceAddressSearchResult(addresses: []);
    }

    final lower = trimmed.toLowerCase();
    final matches = _addresses
        .where(
          (address) =>
              address.roadAddress.contains(trimmed) ||
              (address.jibunAddress?.contains(trimmed) ?? false) ||
              (address.dongName?.contains(trimmed) ?? false) ||
              address.roadAddress.toLowerCase().contains(lower),
        )
        .toList();

    return WorkplaceAddressSearchResult(
      addresses: matches,
      mock: true,
      message: matches.isEmpty
          ? null
          : '주소 API 미연동 — 샘플 주소만 검색됩니다. COMPLIANCE_API_URL 설정을 확인해 주세요.',
    );
  }
}

/// 이전 이름 호환
typedef WorkplaceAddressLocalDataSourceImpl = WorkplaceAddressLocalDataSource;
