import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/geo_distance.dart';

/// 출근 체크용 기기 위치 — 모바일 GPS, 데스크톱(Windows 등)은 완화
abstract final class DeviceLocationService {
  static const checkInRadiusMeters = 500.0;

  static bool get allowsRelaxedLocation =>
      !kIsWeb &&
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  static Future<GeoCoordinate?> getCurrentPosition() async {
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
    return GeoCoordinate(
      latitude: position.latitude,
      longitude: position.longitude,
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
