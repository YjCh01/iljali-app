import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/constants/map_constants.dart';
import 'package:map/core/utils/naver_map_platform.dart';
import 'package:map/features/map_dashboard/data/datasources/map_camera_holder.dart';
import 'package:map/features/map_dashboard/data/repositories/map_repository_impl.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';
import 'package:map/features/map_dashboard/domain/usecases/get_warehouses_usecase.dart';
import 'package:map/features/map_dashboard/presentation/map/warehouse_cluster_options_factory.dart';
import 'package:map/features/map_dashboard/presentation/map/warehouse_marker_factory.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_current_location_button.dart';
import 'package:map/features/map_dashboard/presentation/widgets/map_unavailable_placeholder.dart';

/// 네이버 지도 + 물류센터 마커·클러스터링
class NaverMapBackground extends StatefulWidget {
  const NaverMapBackground({
    super.key,
    this.onMapReady,
    this.onWarehouseTap,
    this.onMapBackgroundTap,
    GetWarehousesUseCase? getWarehousesUseCase,
  }) : _getWarehousesUseCase = getWarehousesUseCase;

  final void Function(NaverMapController controller)? onMapReady;
  final void Function(Warehouse warehouse)? onWarehouseTap;
  final VoidCallback? onMapBackgroundTap;
  final GetWarehousesUseCase? _getWarehousesUseCase;

  @override
  State<NaverMapBackground> createState() => _NaverMapBackgroundState();
}

class _NaverMapBackgroundState extends State<NaverMapBackground> {
  late final GetWarehousesUseCase _getWarehousesUseCase =
      widget._getWarehousesUseCase ??
      GetWarehousesUseCase(MapRepositoryImpl());

  @override
  void dispose() {
    MapCameraHolder.instance.unbind();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!NaverMapPlatform.shouldShowMap) {
      return const MapUnavailablePlaceholder();
    }

    final safeAreaPadding = MediaQuery.paddingOf(context);

    return Stack(
      fit: StackFit.expand,
      children: [
        NaverMap(
          options: NaverMapViewOptions(
            contentPadding: safeAreaPadding,
            initialCameraPosition: const NCameraPosition(
              target: MapConstants.warehouseAreaCenter,
              zoom: MapConstants.warehouseAreaZoom,
            ),
            locationButtonEnable: false,
          ),
          clusterOptions: WarehouseClusterOptionsFactory.create(),
          onMapReady: _handleMapReady,
          onMapTapped: widget.onMapBackgroundTap == null
              ? null
              : (_, __) => widget.onMapBackgroundTap!(),
        ),
        const MapCurrentLocationButton(),
      ],
    );
  }

  Future<void> _handleMapReady(NaverMapController controller) async {
    MapCameraHolder.instance.bind(controller);

    final warehouses = await _getWarehousesUseCase();
    final markers = WarehouseMarkerFactory.createAll(
      warehouses,
      onTap: widget.onWarehouseTap,
    );
    controller.addOverlayAll(markers);

    widget.onMapReady?.call(controller);
  }
}
