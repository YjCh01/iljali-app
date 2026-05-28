import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/map_dashboard/domain/entities/warehouse.dart';

/// 물류센터 → 클러스터 가능 마커 변환
abstract final class WarehouseMarkerFactory {
  static const Size markerSize = Size(32, 42);

  static NClusterableMarker create(
    Warehouse warehouse, {
    void Function(Warehouse warehouse)? onTap,
  }) {
    final marker = NClusterableMarker(
      id: warehouse.id,
      position: warehouse.position,
      tags: const {'type': 'warehouse'},
      iconTintColor: AppColors.primaryLight,
      size: markerSize,
      caption: NOverlayCaption(
        text: warehouse.name,
        color: AppColors.textPrimary,
        haloColor: Colors.white,
        textSize: 12,
      ),
      isHideCollidedCaptions: true,
    );

    if (onTap != null) {
      marker.setOnTapListener((_) => onTap(warehouse));
    }

    return marker;
  }

  static Set<NClusterableMarker> createAll(
    List<Warehouse> warehouses, {
    void Function(Warehouse warehouse)? onTap,
  }) {
    return warehouses.map((w) => create(w, onTap: onTap)).toSet();
  }
}
