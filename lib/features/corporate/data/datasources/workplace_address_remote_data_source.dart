import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/data/datasources/workplace_address_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// FastAPI `/v1/addresses/search` — 행정안전부 Juso 도로명주소 + Kakao 좌표
class WorkplaceAddressRemoteDataSource implements WorkplaceAddressDataSource {
  WorkplaceAddressRemoteDataSource({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = (baseUrl ?? EnvConfig.complianceApiBaseUrl)
            .replaceAll(RegExp(r'/$'), ''),
        _fallback = const WorkplaceAddressLocalDataSource();

  final http.Client _client;
  final String _baseUrl;
  final WorkplaceAddressLocalDataSource _fallback;

  @override
  Future<WorkplaceAddressSearchResult> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const WorkplaceAddressSearchResult(addresses: []);
    }
    if (_baseUrl.isEmpty) {
      return _fallback.search(trimmed);
    }

    try {
      final uri = Uri.parse('$_baseUrl/v1/addresses/search').replace(
        queryParameters: {'q': trimmed},
      );
      final response = await _client.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode >= 400) {
        return WorkplaceAddressSearchResult(
          addresses: const [],
          message: '주소 검색 서버 오류 (${response.statusCode})',
        );
      }

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = map['results'] as List<dynamic>? ?? [];
      final addresses = rows
          .map((row) => _parseRow(row as Map<String, dynamic>))
          .whereType<WorkplaceAddress>()
          .toList();

      return WorkplaceAddressSearchResult(
        addresses: addresses,
        mock: map['mock'] as bool? ?? false,
        message: map['message'] as String?,
      );
    } on Object {
      final fallback = await _fallback.search(trimmed);
      return WorkplaceAddressSearchResult(
        addresses: fallback.addresses,
        mock: true,
        message: '주소 서버에 연결할 수 없어 샘플 데이터를 사용합니다.',
      );
    }
  }

  /// @visibleForTesting
  static WorkplaceAddress? parseRow(Map<String, dynamic> row) => _parseRow(row);

  static WorkplaceAddress? _parseRow(Map<String, dynamic> row) {
    final road = row['road_address'] as String? ?? '';
    if (road.isEmpty) return null;

    GeoCoordinate? coordinate;
    final lat = row['latitude'];
    final lng = row['longitude'];
    if (lat is num && lng is num) {
      coordinate = GeoCoordinate(
        latitude: lat.toDouble(),
        longitude: lng.toDouble(),
      );
    }

    return WorkplaceAddress(
      roadAddress: road,
      jibunAddress: row['jibun_address'] as String?,
      dongName: row['dong_name'] as String?,
      buildingName: row['building_name'] as String?,
      zipCode: row['zip_code'] as String?,
      coordinate: coordinate,
    );
  }
}
