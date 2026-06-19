import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/map_dashboard/data/datasources/map_viewport_session_store.dart';

void main() {
  test('MapViewportSessionStore remembers and peeks snapshots', () {
    final store = MapViewportSessionStore.instance;
    const key = 'test_map';
    store.forget(key);

    expect(store.peek(key), isNull);

    store.rememberCoordinate(
      key,
      center: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
      zoom: 15.5,
    );

    final saved = store.peek(key);
    expect(saved, isNotNull);
    expect(saved!.latitude, 37.5);
    expect(saved.longitude, 127.0);
    expect(saved.zoom, 15.5);

    store.forget(key);
    expect(store.peek(key), isNull);
  });
}
