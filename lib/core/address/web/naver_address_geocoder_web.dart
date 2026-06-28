import 'dart:async';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/core/utils/naver_map_platform.dart';

/// NAVER Maps JS Geocoder — Kakao/JUSO 키 없이 웹에서 도로명 → 좌표
Future<GeoCoordinate?> geocodeWithNaverMaps(String query) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty || !NaverMapPlatform.isWebSupported) return null;

  try {
    await ensureNaverMapsScriptLoaded(NaverMapPlatform.webClientId);
    await _waitForGeocoderService();

    final completer = Completer<GeoCoordinate?>();
    final naver = js_util.getProperty<Object>(html.window, 'naver');
    final maps = js_util.getProperty<Object>(naver, 'maps');
    final service = js_util.getProperty<Object>(maps, 'Service');
    final statusObj = js_util.getProperty<Object>(service, 'Status');
    final okStatus = js_util.getProperty<Object>(statusObj, 'OK');

    final options = js_util.newObject();
    js_util.setProperty(options, 'query', trimmed);

    js_util.callMethod(service, 'geocode', [
      options,
      js_util.allowInterop((Object status, Object response) {
        try {
          if (status != okStatus) {
            completer.complete(null);
            return;
          }
          final v2 = js_util.getProperty<Object?>(response, 'v2');
          if (v2 == null) {
            completer.complete(null);
            return;
          }
          final addresses = js_util.getProperty<Object?>(v2, 'addresses');
          if (addresses == null) {
            completer.complete(null);
            return;
          }
          final length = js_util.getProperty<int>(addresses, 'length');
          if (length == 0) {
            completer.complete(null);
            return;
          }
          final first = js_util.getProperty<Object>(addresses, '0');
          final x = js_util.getProperty<Object?>(first, 'x');
          final y = js_util.getProperty<Object?>(first, 'y');
          if (x == null || y == null) {
            completer.complete(null);
            return;
          }
          completer.complete(
            GeoCoordinate(
              latitude: double.parse(y.toString()),
              longitude: double.parse(x.toString()),
            ),
          );
        } on Object {
          if (!completer.isCompleted) completer.complete(null);
        }
      }),
    ]);

    return completer.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () => null,
    );
  } on Object {
    return null;
  }
}

Future<void> _waitForGeocoderService() async {
  final deadline = DateTime.now().add(const Duration(seconds: 8));
  while (DateTime.now().isBefore(deadline)) {
    final naver = js_util.getProperty<Object?>(html.window, 'naver');
    if (naver != null) {
      final maps = js_util.getProperty<Object?>(naver, 'maps');
      if (maps != null) {
        final service = js_util.getProperty<Object?>(maps, 'Service');
        if (service != null &&
            js_util.getProperty<Object?>(service, 'geocode') != null) {
          return;
        }
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
}
