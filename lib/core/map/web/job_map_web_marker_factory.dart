import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/core/map/web/naver_map_web_layer.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

/// JobMapPin → NAVER Maps JS 웹 마커 스펙
abstract final class JobMapWebMarkerFactory {
  static MapPinMarkerKind _kindFor(JobMapPin pin) {
    if (pin.isClosedGhost) return MapPinMarkerKind.workplace;
    return switch (TeardropMapPinArt.styleForTier(pin.displayTier)) {
      MapPinStyle.notification => MapPinMarkerKind.notification,
      MapPinStyle.busStop => MapPinMarkerKind.busStop,
      MapPinStyle.workplace => MapPinMarkerKind.workplace,
    };
  }

  static NaverMapWebMarkerSpec fromPin(
    JobMapPin pin, {
    bool isOwn = false,
    bool isSelected = false,
  }) {
    final kind = _kindFor(pin);
    final bodyColor = isSelected
        ? MapPinColors.selected
        : pin.isClosedGhost
            ? MapPinColors.ghost
            : MapPinColors.active;
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
