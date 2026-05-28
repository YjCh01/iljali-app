import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/constants/app_colors.dart';

/// 물류센터 마커 클러스터링 옵션
abstract final class WarehouseClusterOptionsFactory {
  static NaverMapClusteringOptions create() {
    return NaverMapClusteringOptions(
      mergeStrategy: const NClusterMergeStrategy(
        willMergedScreenDistance: {
          NInclusiveRange(0, 12): 90,
          NInclusiveRange(13, 15): 55,
          NInclusiveRange(16, 20): 30,
        },
      ),
      animationDuration: const Duration(milliseconds: 250),
      clusterMarkerBuilder: _buildClusterMarker,
    );
  }

  static void _buildClusterMarker(NClusterInfo info, NClusterMarker clusterMarker) {
    clusterMarker
      ..setIconTintColor(AppColors.primaryLight)
      ..setSize(const Size(52, 52))
      ..setCaption(
        NOverlayCaption(
          text: '${info.size}',
          color: Colors.white,
          textSize: 15,
          haloColor: Colors.transparent,
        ),
      )
      ..setCaptionAligns(const [NAlign.center]);
  }
}
