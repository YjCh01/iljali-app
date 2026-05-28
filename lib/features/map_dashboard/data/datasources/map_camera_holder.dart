import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/features/map_dashboard/domain/entities/map_location.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';

/// NaverMapController 참조 — 카메라 이동·중심 좌표 조회
class MapCameraHolder {
  MapCameraHolder._();

  static final MapCameraHolder instance = MapCameraHolder._();

  NaverMapController? _controller;

  bool get isReady => _controller != null;

  void bind(NaverMapController controller) => _controller = controller;

  void unbind() => _controller = null;

  Future<MapLocation> getCurrentCenter() async {
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

  Future<void> focusWarehouse(Warehouse warehouse) async {
    final controller = _controller;
    if (controller == null) return;

    await controller.updateCamera(
      NCameraUpdate.withParams(
        target: warehouse.position,
        zoom: 15,
      ),
    );
  }
}
