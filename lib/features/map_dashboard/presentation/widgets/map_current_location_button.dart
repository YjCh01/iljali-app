import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/geo/map_user_location_service.dart';

/// 지도 좌측 하단 — 현재 위치로 이동 (네이버 기본 버튼 대체)
class MapCurrentLocationButton extends StatelessWidget {
  const MapCurrentLocationButton({
    super.key,
    this.controller,
    this.onPressed,
    this.onMockLocate,
    this.bottom = 16,
    this.left = 16,
  });

  final NaverMapController? controller;
  final VoidCallback? onPressed;
  final Future<bool> Function()? onMockLocate;
  final double bottom;
  final double left;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      bottom: bottom,
      child: Material(
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onPressed ?? () => _handleTap(context),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              Icons.my_location_rounded,
              size: 22,
              color: Color(0xFF757575),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    if (onMockLocate != null) {
      final moved = await onMockLocate!();
      if (!context.mounted) return;
      if (!moved) {
        MapUserLocationService.showLocationUnavailableMessage(context);
      }
      return;
    }
    await MapUserLocationService.handleLocationButtonTap(
      context,
      controller: controller,
    );
  }
}
