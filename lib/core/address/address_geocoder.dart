import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:map/core/address/map_backed_address_geocoder_stub.dart'
    if (dart.library.html) 'package:map/core/address/map_backed_address_geocoder_web.dart'
    if (dart.library.io) 'package:map/core/address/map_backed_address_geocoder_io.dart'
    as map_backed_geocoder;
import 'package:map/core/config/env_config.dart';
import 'package:map/core/geo/geo_coordinate.dart';

/// 도로명/지번 주소 → 좌표
///
/// 1. FastAPI `/v1/addresses/geocode` · `/search` (COMPLIANCE_API_URL)
/// 2. 웹: NAVER Maps JS Geocoder · 앱: iOS/Android 플랫폼 Geocoder
/// 3. Kakao Local REST (`KAKAO_REST_API_KEY`)
abstract final class AddressGeocoder {
  static const _addressUrl =
      'https://dapi.kakao.com/v2/local/search/address.json';

  static Future<GeoCoordinate?> geocode(String query, {http.Client? client}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return null;

    if (EnvConfig.isComplianceApiEnabled) {
      final viaGeocode =
          await _geocodeViaComplianceGeocodeEndpoint(trimmed, client: client);
      if (viaGeocode != null) return viaGeocode;

      final viaServer = await _geocodeViaComplianceApi(trimmed, client: client);
      if (viaServer != null) return viaServer;
    }

    final viaMapStack =
        await map_backed_geocoder.geocodeWithoutRemoteAddressKeys(trimmed);
    if (viaMapStack != null) return viaMapStack;

    return _geocodeViaKakaoRest(trimmed, client: client);
  }

  static Future<GeoCoordinate?> _geocodeViaComplianceGeocodeEndpoint(
    String query, {
    http.Client? client,
  }) async {
    final base = EnvConfig.complianceApiBaseUrl.replaceAll(RegExp(r'/$'), '');
    if (base.isEmpty) return null;

    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    try {
      final uri = Uri.parse('$base/v1/addresses/geocode').replace(
        queryParameters: {'q': query},
      );
      final response =
          await httpClient.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode >= 400) return null;

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final lat = map['latitude'];
      final lng = map['longitude'];
      if (lat is num && lng is num) {
        return GeoCoordinate(
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
        );
      }
      return null;
    } on Object {
      return null;
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  static Future<GeoCoordinate?> _geocodeViaComplianceApi(
    String query, {
    http.Client? client,
  }) async {
    final base = EnvConfig.complianceApiBaseUrl.replaceAll(RegExp(r'/$'), '');
    if (base.isEmpty) return null;

    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    try {
      final uri = Uri.parse('$base/v1/addresses/search').replace(
        queryParameters: {'q': query},
      );
      final response =
          await httpClient.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode >= 400) return null;

      final map = jsonDecode(response.body) as Map<String, dynamic>;
      final rows = map['results'] as List<dynamic>? ?? [];
      if (rows.isEmpty) return null;

      final row = rows.first as Map<String, dynamic>;
      final lat = row['latitude'];
      final lng = row['longitude'];
      if (lat is num && lng is num) {
        return GeoCoordinate(
          latitude: lat.toDouble(),
          longitude: lng.toDouble(),
        );
      }
      return null;
    } on Object {
      return null;
    } finally {
      if (shouldCloseClient) {
        httpClient.close();
      }
    }
  }

  static Future<GeoCoordinate?> _geocodeViaKakaoRest(
    String query, {
    http.Client? client,
  }) async {
    final key = EnvConfig.kakaoRestApiKey;
    if (!EnvConfig.isKakaoAddressConfigured) return null;

    final httpClient = client ?? http.Client();
    final shouldCloseClient = client == null;
    try {
      final response = await httpClient.get(
        Uri.parse(_addressUrl).replace(queryParameters: {
          'query': query,
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
