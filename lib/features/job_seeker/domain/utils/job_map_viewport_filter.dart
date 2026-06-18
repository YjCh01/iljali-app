import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:map/core/geo/map_viewport_bounds.dart';

MapViewportBounds mapViewportFromNaverBounds(NLatLngBounds bounds) {
  return MapViewportBounds(
    north: bounds.northEast.latitude,
    south: bounds.southWest.latitude,
    east: bounds.northEast.longitude,
    west: bounds.southWest.longitude,
  );
}

List<T> filterPinsInViewport<T>({
  required List<T> pins,
  required MapViewportBounds viewport,
  required double Function(T pin) latitude,
  required double Function(T pin) longitude,
}) {
  return pins
      .where(
        (pin) => viewport.contains(
          latitude: latitude(pin),
          longitude: longitude(pin),
        ),
      )
      .toList();
}
