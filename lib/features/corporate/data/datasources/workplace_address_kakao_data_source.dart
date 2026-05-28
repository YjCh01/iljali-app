import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/data/datasources/workplace_address_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// Kakao Local API — 서버 없이도 전국 주소 검색 (REST API 키만 필요)
class WorkplaceAddressKakaoDataSource implements WorkplaceAddressDataSource {
  WorkplaceAddressKakaoDataSource({http.Client? client})
      : _client = client ?? http.Client();

  final http.Client _client;
  static const _keywordUrl =
      'https://dapi.kakao.com/v2/local/search/keyword.json';
  static const _addressUrl =
      'https://dapi.kakao.com/v2/local/search/address.json';

  @override
  Future<WorkplaceAddressSearchResult> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const WorkplaceAddressSearchResult(addresses: []);
    }

    final key = EnvConfig.kakaoRestApiKey;
    if (key.isEmpty) {
      return const WorkplaceAddressLocalDataSource().search(trimmed);
    }

    try {
      final keyword = await _fetchKeyword(trimmed, key);
      if (keyword.isNotEmpty) {
        return WorkplaceAddressSearchResult(addresses: keyword);
      }
      final address = await _fetchAddress(trimmed, key);
      return WorkplaceAddressSearchResult(addresses: address);
    } on Object {
      return WorkplaceAddressSearchResult(
        addresses: const [],
        message: 'Kakao 주소 검색에 실패했습니다.',
      );
    }
  }

  Future<List<WorkplaceAddress>> _fetchKeyword(String query, String key) async {
    final response = await _client.get(
      Uri.parse(_keywordUrl).replace(queryParameters: {
        'query': query,
        'size': '15',
      }),
      headers: {'Authorization': 'KakaoAK $key'},
    );
    if (response.statusCode >= 400) return [];
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['documents'] as List<dynamic>? ?? [])
        .map((row) => _fromKakaoDoc(row as Map<String, dynamic>))
        .whereType<WorkplaceAddress>()
        .toList();
  }

  Future<List<WorkplaceAddress>> _fetchAddress(String query, String key) async {
    final response = await _client.get(
      Uri.parse(_addressUrl).replace(queryParameters: {
        'query': query,
        'size': '15',
      }),
      headers: {'Authorization': 'KakaoAK $key'},
    );
    if (response.statusCode >= 400) return [];
    final map = jsonDecode(response.body) as Map<String, dynamic>;
    return (map['documents'] as List<dynamic>? ?? [])
        .map((row) => _fromKakaoDoc(row as Map<String, dynamic>))
        .whereType<WorkplaceAddress>()
        .toList();
  }

  static WorkplaceAddress? _fromKakaoDoc(Map<String, dynamic> doc) {
    final road = (doc['road_address_name'] as String? ?? '').trim();
    final jibun = (doc['address_name'] as String? ?? '').trim();
    final roadAddress = road.isNotEmpty ? road : jibun;
    if (roadAddress.isEmpty) return null;

    GeoCoordinate? coordinate;
    try {
      coordinate = GeoCoordinate(
        latitude: double.parse(doc['y'] as String),
        longitude: double.parse(doc['x'] as String),
      );
    } on Object {
      coordinate = null;
    }

    return WorkplaceAddress(
      roadAddress: roadAddress,
      jibunAddress: jibun.isEmpty ? null : jibun,
      dongName: (doc['region_3depth_name'] as String?)?.trim(),
      buildingName: (doc['place_name'] as String?)?.trim(),
      coordinate: coordinate,
    );
  }
}
