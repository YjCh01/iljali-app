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
        : switch (pin.displayTier) {
            // 근무지 핀은 알림핀/유료 티어 색을 쓰지 않음
            JobMapPinDisplayTier.packageActive => MapPinColors.freeGray,
            _ => pin.displayTier.pinColor,
          };

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
}
