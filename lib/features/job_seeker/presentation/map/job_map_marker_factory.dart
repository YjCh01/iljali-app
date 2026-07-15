import 'package:flutter/material.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 채용 공고 → 클러스터 가능 마커 (근무지 / 알림 / 유령)
abstract final class JobMapMarkerFactory {
  static MapPinStyle _styleFor(JobMapPin pin) => MapPinStyle.workplace;

  static Future<NClusterableMarker> create(
    JobMapPin pin, {
    void Function(JobMapPin pin)? onTap,
    bool isOwn = false,
    bool isSelected = false,
  }) async {
    var scale = 1.0;
    if (isSelected) {
      scale = 1.12;
    } else if (isOwn) {
      scale = 1.06;
    }

    final style = _styleFor(pin);
    final bodyColor = isSelected
        ? MapPinColors.selected
        : _bodyColorFor(pin);

    final icon = await MapPinOverlayIconCache.pin(
      style: style,
      bodyColor: bodyColor,
      selected: isSelected,
      scale: scale,
    );

    final (w, h) = switch (style) {
      MapPinStyle.busStop => (
          TeardropMapPinArt.busWidth * scale,
          TeardropMapPinArt.busHeight * scale,
        ),
      _ => (
          TeardropMapPinArt.pinWidth * scale,
          TeardropMapPinArt.pinHeight * scale,
        ),
    };

    final marker = NClusterableMarker(
      id: pin.mapMarkerId,
      position: NLatLng(pin.latitude, pin.longitude),
      tags: {
        'type': pin.isEvent
            ? 'event'
            : pin.isClosedGhost
                ? 'closed_ghost'
                : 'job_post',
        'pin_tier': pin.displayTier.name,
        if (isOwn) 'own': '1',
        if (isSelected) 'selected': '1',
      },
      icon: icon,
      size: Size(w, h),
      caption: null,
      isHideCollidedCaptions: true,
    );

    if (onTap != null) {
      marker.setOnTapListener((_) => onTap(pin));
    }

    return marker;
  }

  static Color _bodyColorFor(JobMapPin pin) {
    if (pin.isEvent) {
      final hex = pin.eventPin?.colorHex;
      final parsed = _parseHex(hex);
      if (parsed != null) return parsed;
      return pin.displayTier.pinColor;
    }
    return switch (pin.displayTier) {
      JobMapPinDisplayTier.packageActive => MapPinColors.freeGray,
      _ => pin.displayTier.pinColor,
    };
  }

  static Color? _parseHex(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var value = hex.replaceFirst('#', '');
    if (value.length == 6) value = 'FF$value';
    if (value.length != 8) return null;
    final parsed = int.tryParse(value, radix: 16);
    if (parsed == null) return null;
    return Color(parsed);
  }

  static Future<Set<NClusterableMarker>> createAll(
    List<JobMapPin> pins, {
    void Function(JobMapPin pin)? onTap,
    Set<String>? ownPostIds,
    String? selectedPostId,
  }) async {
    final markers = <NClusterableMarker>{};
    for (final pin in pins) {
      markers.add(
        await create(
          pin,
          onTap: onTap,
          isOwn: ownPostIds?.contains(pin.post.id) ?? false,
          isSelected: selectedPostId != null &&
              (selectedPostId == pin.post.id ||
                  selectedPostId == pin.mapMarkerId),
        ),
      );
    }
    return markers;
  }
}
