import 'package:flutter/material.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// JobMapPin → NAVER Maps JS 웹 마커 스펙
abstract final class JobMapWebMarkerFactory {
  static MapPinMarkerKind _kindFor(JobMapPin pin) =>
      MapPinMarkerKind.workplace;

  static NaverMapWebMarkerSpec fromPin(
    JobMapPin pin, {
    bool isOwn = false,
    bool isSelected = false,
  }) {
    final kind = _kindFor(pin);
    final bodyColor = isSelected
        ? MapPinColors.selected
        : _bodyColorFor(pin);

    var scale = 1.0;
    if (isSelected) {
      scale = 1.12;
    } else if (isOwn) {
      scale = 1.06;
    }

    final (w, h) = kind == MapPinMarkerKind.busStop
        ? (
            TeardropMapPinArt.busWidth * scale,
            TeardropMapPinArt.busHeight * scale,
          )
        : (
            TeardropMapPinArt.pinWidth * scale,
            TeardropMapPinArt.pinHeight * scale,
          );

    return NaverMapWebMarkerSpec(
      id: pin.mapMarkerId,
      latitude: pin.latitude,
      longitude: pin.longitude,
      colorHex: NaverMapWebColors.hex(bodyColor),
      borderColorHex: NaverMapWebColors.hex(bodyColor),
      ringColorHex: null,
      ringWidth: 0,
      label: '',
      isOwn: isOwn,
      isSelected: isSelected,
      kind: kind,
      size: w,
      height: h,
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
            isSelected: selectedPostId != null &&
                (selectedPostId == pin.post.id ||
                    selectedPostId == pin.mapMarkerId),
          ),
        )
        .toList();
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
}
