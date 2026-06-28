import 'package:map/core/geo/geo_coordinate.dart';

/// Last camera center + zoom for a logical map surface (survives route push/pop).
class MapViewportSnapshot {
  const MapViewportSnapshot({
    required this.latitude,
    required this.longitude,
    required this.zoom,
  });

  final double latitude;
  final double longitude;
  final double zoom;

  GeoCoordinate get center =>
      GeoCoordinate(latitude: latitude, longitude: longitude);

  factory MapViewportSnapshot.fromCoordinate({
    required GeoCoordinate coordinate,
    required double zoom,
  }) {
    return MapViewportSnapshot(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      zoom: zoom,
    );
  }
}

/// In-memory viewport cache keyed by map context (page + optional sub-scope).
class MapViewportSessionStore {
  MapViewportSessionStore._();

  static final MapViewportSessionStore instance = MapViewportSessionStore._();

  final Map<String, MapViewportSnapshot> _snapshots = {};

  MapViewportSnapshot? peek(String key) => _snapshots[key];

  void remember(String key, MapViewportSnapshot snapshot) {
    _snapshots[key] = snapshot;
  }

  void rememberCoordinate(
    String key, {
    required GeoCoordinate center,
    required double zoom,
  }) {
    remember(
      key,
      MapViewportSnapshot.fromCoordinate(coordinate: center, zoom: zoom),
    );
  }

  void forget(String key) => _snapshots.remove(key);
}

/// Stable keys for corporate / push map flows.
abstract final class MapViewportSessionKeys {
  static const corporateHome = 'corporate_home_map';

  static String pushBasePoint(String pointId) => 'push_base_point_$pointId';

  static const jobPinActivation = 'job_pin_activation_map';

  static const pushTicketUse = 'push_ticket_use_map';

  static const extraPushConfirm = 'extra_push_confirm_map';

  static const seekerHomeMap = 'seeker_home_map';
}
