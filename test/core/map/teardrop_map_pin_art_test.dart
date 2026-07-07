import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/map/pins/teardrop_map_pin_art.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

void main() {
  test('bus stop html uses rounded square path', () {
    final html = TeardropMapPinArt.pinHtml(
      style: MapPinStyle.busStop,
      bodyHex: '#6BAED6',
      width: 34,
      height: 44,
    );
    expect(html, contains('linearGradient'));
    expect(html, contains('<path'));
    expect(html, isNot(contains('fill-rule="evenodd"')));
  });

  test('notification pin html uses ring teardrop with larger hole', () {
    final html = TeardropMapPinArt.pinHtml(
      style: MapPinStyle.notification,
      bodyHex: '#6BAED6',
      width: 38,
      height: 50,
    );
    expect(html, contains('fill-rule="evenodd"'));
    expect(html, contains('linearGradient'));
  });

  test('workplace pin html uses ring teardrop', () {
    final html = TeardropMapPinArt.pinHtml(
      style: MapPinStyle.workplace,
      bodyHex: '#9E9E9E',
      width: 38,
      height: 50,
    );
    expect(html, contains('fill-rule="evenodd"'));
    expect(html, contains('#9E9E9E'));
  });

  test('styleForTier maps packageActive to notification', () {
    expect(
      TeardropMapPinArt.styleForTier(JobMapPinDisplayTier.packageActive),
      MapPinStyle.notification,
    );
    expect(
      TeardropMapPinArt.styleForTier(JobMapPinDisplayTier.standard),
      MapPinStyle.workplace,
    );
  });
}
