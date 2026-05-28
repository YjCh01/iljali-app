import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 채용 공고 → 클러스터 가능 마커 (등급별 크기·색상)
abstract final class JobMapMarkerFactory {
  static NClusterableMarker create(
    JobMapPin pin, {
    void Function(JobMapPin pin)? onTap,
  }) {
    final tier = pin.displayTier;
    final size = tier.markerSize;

    final marker = NClusterableMarker(
      id: pin.post.id,
      position: NLatLng(pin.latitude, pin.longitude),
      tags: {
        'type': 'job_post',
        'pin_tier': tier.name,
      },
      iconTintColor: tier.pinColor,
      size: Size(size, size),
      caption: NOverlayCaption(
        text: tier == JobMapPinDisplayTier.standard
            ? '1'
            : tier.shapeGlyph,
        color: Colors.white,
        haloColor: Colors.transparent,
        textSize: tier == JobMapPinDisplayTier.premiumPartner ? 16 : 14,
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
  }) {
    return pins.map((pin) => create(pin, onTap: onTap)).toSet();
  }
}
