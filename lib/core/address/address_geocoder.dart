import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/config/env_config.dart';
import 'package:map/core/geo/geo_coordinate.dart';

/// 도로명/지번 주소 → 좌표 (Kakao Local REST API)
abstract final class AddressGeocoder {
  static const _addressUrl =
      'https://dapi.kakao.com/v2/local/search/address.json';

  static Future<GeoCoordinate?> geocode(String query, {http.Client? client}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    final key = EnvConfig.kakaoRestApiKey;
    if (!EnvConfig.isKakaoAddressConfigured) return null;

    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    try {
      final response = await httpClient.get(
        Uri.parse(_addressUrl).replace(queryParameters: {
          'query': trimmed,
          'size': '1',
        }),
        headers: {'Authorization': 'KakaoAK $key'},
      );
      if (response.statusCode >= 400) return null;

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final documents = map['documents'] as List<dynamic>? ?? [];
      if (documents.isEmpty) return null;

      final doc = documents.first as Map<String, dynamic>;
      return GeoCoordinate(
        latitude: double.parse(doc['y'] as String),
        longitude: double.parse(doc['x'] as String),
      );
    } on Object {
      return null;
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }
}
