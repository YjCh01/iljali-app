import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/utils/naver_directions_url.dart';

void main() {
  test('buildNaverDirectionsUrl walk mode uses lng,lat order', () {
    final url = buildNaverDirectionsUrl(
      destinationLabel: '물류센터',
      destinationLatitude: 37.5,
      destinationLongitude: 127.0,
      originLatitude: 37.49,
      originLongitude: 126.99,
      mode: NaverDirectionsMode.walk,
    );

    expect(
      url,
      'https://map.naver.com/v5/directions/126.990000,37.490000/127.000000,37.500000/-/walk',
    );
  });

  test('buildNaverDirectionsUrl falls back to encoded labels', () {
    final url = buildNaverDirectionsUrl(
      destinationLabel: '서울 물류센터',
      originLabel: '서울시 강남구',
      mode: NaverDirectionsMode.walk,
    );

    expect(url, contains('/-/walk'));
    expect(url, contains(Uri.encodeComponent('서울 물류센터')));
    expect(url, contains(Uri.encodeComponent('서울시 강남구')));
  });
}
