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

  Future<void> focusPin({
    required double latitude,
    required double longitude,
    double zoom = 14,
  }) async {
    final web = _webController;
    if (web != null && web.isReady) {
      await web.moveCamera(
        latitude: latitude,
        longitude: longitude,
        zoom: zoom,
      );
      return;
    }

    final controller = _controller;
    if (controller == null) return;

    await controller.updateCamera(
      NCameraUpdate.withParams(
        target: NLatLng(latitude, longitude),
        zoom: zoom,
      ),
    );
  }
}
