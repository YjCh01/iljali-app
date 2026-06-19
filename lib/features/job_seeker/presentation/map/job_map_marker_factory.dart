import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 채용 공고 → 클러스터 가능 마커 (등급별 크기·색상)
abstract final class JobMapMarkerFactory {
  static NClusterableMarker create(
    JobMapPin pin, {
    void Function(JobMapPin pin)? onTap,
    bool isOwn = false,
    bool isSelected = false,
  }) {
    final tier = pin.displayTier;
    var size = tier.markerSize;
    if (isSelected) size *= 1.18;
    else if (isOwn) size *= 1.06;

    final marker = NClusterableMarker(
      id: pin.post.id,
      position: NLatLng(pin.latitude, pin.longitude),
      tags: {
        'type': 'job_post',
        'pin_tier': tier.name,
        if (isOwn) 'own': '1',
        if (isSelected) 'selected': '1',
      },
      iconTintColor: isSelected
          ? const Color(0xFFFF6F00)
          : isOwn
              ? AppColors.primary
              : tier.pinColor,
      size: Size(size, size),
      caption: NOverlayCaption(
        text: tier == JobMapPinDisplayTier.standard
            ? '1'
            : tier.shapeGlyph,
        color: Colors.white,
        haloColor: Colors.transparent,
        textSize: 14,
      ),
      isHideCollidedCaptions: true,
    );

    if (onTap != null) {
      marker.setOnTapListener((_) => onTap(pin));
    }

    return marker;
  }

  static Set<NClusterableMarker> createAll(
    List<JobMapPin> pins, {
    void Function(JobMapPin pin)? onTap,
    Set<String>? ownPostIds,
    String? selectedPostId,
  }) {
    return pins
        .map(
          (pin) => create(
            pin,
            onTap: onTap,
            isOwn: ownPostIds?.contains(pin.post.id) ?? false,
            isSelected: selectedPostId == pin.post.id,
          ),
        )
        .toSet();
  }
}
