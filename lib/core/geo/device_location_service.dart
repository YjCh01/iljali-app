import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map/core/geo/device_position_result.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';

/// 출근 체크용 기기 위치 — 모바일 GPS, 데스크톱(Windows 등)은 완화
abstract final class DeviceLocationService {
  /// 근무지 지오펜스 반경 (미터)
  static const checkInRadiusMeters = 200.0;

  static bool get allowsRelaxedLocation =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static Future<GeoCoordinate?> getCurrentPosition() async {
    final detailed = await getCurrentPositionDetailed();
    return detailed?.coordinate;
  }

  static Future<DevicePositionResult?> getCurrentPositionDetailed() async {
    if (allowsRelaxedLocation) {
      return null;
    }

    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return DevicePositionResult(
      coordinate: GeoCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
      ),
      isMocked: position.isMocked,
      accuracyMeters: position.accuracy,
    );
  }

  static bool isWithinCheckInRadius({
    required GeoCoordinate current,
    required GeoCoordinate workplace,
    double radiusMeters = checkInRadiusMeters,
  }) {
    return GeoDistance.metersBetween(current, workplace) <= radiusMeters;
  }
}
