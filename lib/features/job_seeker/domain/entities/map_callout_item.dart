import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/commute/domain/entities/commute_route_stop.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';

/// 핀 스와이프 캐러셀에 들어가는 항목 — 공고핀 또는 셔틀 정류장핀.
sealed class MapCalloutItem {
  const MapCalloutItem();

  double get latitude;
  double get longitude;
  String get calloutId;
}

class JobPinCalloutItem extends MapCalloutItem {
  const JobPinCalloutItem(this.pin);

  final JobMapPin pin;

  @override
  double get latitude => pin.latitude;

  @override
  double get longitude => pin.longitude;

  @override
  String get calloutId => 'job_${pin.post.id}';
}

class ShuttleStopCalloutItem extends MapCalloutItem {
  const ShuttleStopCalloutItem({required this.route, required this.stop});

  final CommuteRoute route;
  final CommuteRouteStop stop;

  @override
  double get latitude => stop.coordinate.latitude;

  @override
  double get longitude => stop.coordinate.longitude;

  @override
  String get calloutId => 'stop_${route.id}_${stop.id}';
}
