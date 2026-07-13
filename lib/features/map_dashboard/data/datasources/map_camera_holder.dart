import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/geo/map_viewport_bounds.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/features/map_dashboard/domain/entities/map_location.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';

/// 지도 카메라 참조 — 네이티브 NaverMapController · 웹 NaverMapWebController
class MapCameraHolder {
  MapCameraHolder._();

  static final MapCameraHolder instance = MapCameraHolder._();

  NaverMapController? _controller;
  NaverMapWebController? _webController;

  bool get isReady =>
      _controller != null || (_webController?.isReady ?? false);

  NaverMapController? get controller => _controller;

  NaverMapWebController? get webController => _webController;

  void bind(NaverMapController controller) {
    _controller = controller;
    _webController = null;
  }

  void bindWeb(NaverMapWebController controller) {
    _webController = controller;
    _controller = null;
  }

  void unbind() {
    _controller = null;
    _webController = null;
  }

  Future<MapLocation> getCurrentCenter() async {
    final web = _webController;
    if (web != null && web.isReady) {
      final bounds = await web.getViewportBounds();
      final lat = (bounds.north + bounds.south) / 2;
      final lng = (bounds.east + bounds.west) / 2;
      return MapLocation(latitude: lat, longitude: lng);
    }

    final controller = _controller;
    if (controller == null) {
      return MapLocation(
        latitude: MapConstants.warehouseAreaCenter.latitude,
        longitude: MapConstants.warehouseAreaCenter.longitude,
        label: '기본 영역',
      );
    }

    final camera = await controller.getCameraPosition();
    return MapLocation(
      latitude: camera.target.latitude,
      longitude: camera.target.longitude,
    );
  }

  Future<MapViewportBounds> getViewportBounds() async {
    final web = _webController;
    if (web != null && web.isReady) {
      return web.getViewportBounds();
    }

    final controller = _controller;
    if (controller == null) {
      final center = MapConstants.warehouseAreaCenter;
      return MapViewportBounds.fromCenter(
        centerLat: center.latitude,
        centerLng: center.longitude,
        latSpan: 0.06,
        lngSpan: 0.06,
      );
    }
    final bounds = await controller.getContentBounds(withPadding: true);
    return MapViewportBounds(
      north: bounds.northEast.latitude,
      south: bounds.southWest.latitude,
      east: bounds.northEast.longitude,
      west: bounds.southWest.longitude,
    );
  }

  Future<void> focusWarehouse(Warehouse warehouse) async {
    await focusPin(
      latitude: warehouse.position.latitude,
      longitude: warehouse.position.longitude,
    );
  }

  /// [zoom]이 null이면 현재 축척을 유지하고 중심만 이동합니다.
  ///
  /// [pinScreenY] — 핀이 놓일 화면 Y 비율 (0=상단, 0.5=중앙).
  /// 콜아웃이 하단을 가릴 때 `MapFloatingInsets.calloutPinScreenY` 사용.
  Future<void> focusPin({
    required double latitude,
    required double longitude,
    double? zoom,
    double pinScreenY = 0.5,
  }) async {
    final clampedY = pinScreenY.clamp(0.15, 0.85);

    final web = _webController;
    if (web != null && web.isReady) {
      var targetLat = latitude;
      if ((clampedY - 0.5).abs() > 0.01) {
        final bounds = await web.getViewportBounds();
        final latSpan = (bounds.north - bounds.south).abs();
        if (latSpan > 0) {
          // 핀을 위로 올리려면 카메라 중심을 남쪽으로.
          targetLat = latitude + (0.5 - clampedY) * latSpan;
        }
      }
      await web.moveCamera(
        latitude: targetLat,
        longitude: longitude,
        zoom: zoom,
      );
      return;
    }

    final controller = _controller;
    if (controller == null) return;

    final effectiveZoom = zoom ?? (await controller.getCameraPosition()).zoom;
    final update = NCameraUpdate.withParams(
      target: NLatLng(latitude, longitude),
      zoom: effectiveZoom,
    );
    if ((clampedY - 0.5).abs() > 0.01) {
      update.setPivot(NPoint(0.5, clampedY));
    }
    await controller.updateCamera(update);
  }
}
