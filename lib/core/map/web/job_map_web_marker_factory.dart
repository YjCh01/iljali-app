import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// JobMapPin → NAVER Maps JS 웹 마커 스펙
abstract final class JobMapWebMarkerFactory {
  static NaverMapWebMarkerSpec fromPin(
    JobMapPin pin, {
    bool isOwn = false,
    bool isSelected = false,
  }) {
    final tier = pin.displayTier;
    final color = isSelected
        ? const Color(0xFFFF6F00)
        : isOwn
            ? AppColors.primary
            : tier.pinColor;
    final label = tier == JobMapPinDisplayTier.standard ? '1' : tier.shapeGlyph;

    return NaverMapWebMarkerSpec(
      id: pin.post.id,
      latitude: pin.latitude,
      longitude: pin.longitude,
      colorHex: NaverMapWebColors.hex(color),
      label: label,
      isOwn: isOwn,
      isSelected: isSelected,
    );
  }

  static List<NaverMapWebMarkerSpec> fromPins(
    List<JobMapPin> pins, {
    Set<String>? ownPostIds,
    String? selectedPostId,
  }) {
    return pins
        .map(
          (pin) => fromPin(
            pin,
            isOwn: ownPostIds?.contains(pin.post.id) ?? false,
            isSelected: selectedPostId == pin.post.id,
          ),
        )
        .toList();
  }
}
