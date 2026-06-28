import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/geo/device_location_service.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/geo/location_consent_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';

/// 지도 화면 — 위치 권한 요청 + 현재 위치 표시
abstract final class MapUserLocationService {
  static bool get isSupported =>
      NaverMapPlatform.shouldUseWebMap ||
      (NaverMapPlatform.shouldUseNativeMap &&
          !DeviceLocationService.allowsRelaxedLocation);

  /// 권한 요청 후 위치 조회 가능 여부
  static Future<bool> prepareForMap() async {
    if (!isSupported) return false;
    final position = await DeviceLocationService.getCurrentPosition();
    return position != null;
  }

  static Future<void> handleLocationButtonTap(
    BuildContext context, {
    NaverMapController? controller,
  }) async {
    final user = AuthSession.instance.currentUser;
    if (user?.isIndividual == true) {
      final granted = await LocationConsentService.ensureGranted(
        context,
        trigger: LocationConsentTrigger.mapBrowse,
      );
      if (!granted || !context.mounted) return;
    }

    final web = MapCameraHolder.instance.webController;
    if (web != null && web.isReady) {
      await web.moveToCurrentLocation();
      return;
    }

    final resolved = controller ?? MapCameraHolder.instance.controller;
    if (resolved == null) {
      showLocationUnavailableMessage(context, message: '지도를 불러오는 중입니다.');
      return;
    }

    final moved = await focusMapOnUser(resolved);
    if (!context.mounted) return;
    if (!moved) {
      showLocationUnavailableMessage(context);
    }
  }

  static void showLocationUnavailableMessage(
    BuildContext context, {
    String? message,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ??
              (isSupported
                  ? '위치 권한을 허용하거나 GPS를 켜 주세요.'
                  : '실제 기기에서 위치 권한을 허용해 주세요.'),
        ),
      ),
    );
  }

  static Future<bool> focusMapOnUser(
    NaverMapController controller, {
    double minZoom = 16,
  }) async {
    final position = await DeviceLocationService.getCurrentPosition();
    if (position == null) return false;
    await _moveCamera(controller, position, minZoom: minZoom);
    return true;
  }

  static Future<void> _moveCamera(
    NaverMapController controller,
    GeoCoordinate coordinate, {
    required double minZoom,
  }) async {
    final camera = await controller.getCameraPosition();
    final zoom = camera.zoom < minZoom ? minZoom : camera.zoom;
    final update = NCameraUpdate.withParams(
      target: NLatLng(coordinate.latitude, coordinate.longitude),
      zoom: zoom,
    );
    update.setAnimation(
      animation: NCameraAnimation.easing,
      duration: const Duration(milliseconds: 350),
    );
    await controller.updateCamera(update);
  }
}
