import 'package:web/web.dart' as web;

enum NaverDirectionsMode { car, transit, walk }

Future<bool> openNaverDirections({
  required String destinationLabel,
  double? destinationLatitude,
  double? destinationLongitude,
  double? originLatitude,
  double? originLongitude,
  NaverDirectionsMode mode = NaverDirectionsMode.car,
}) async {
  final trimmed = destinationLabel.trim();
  if (trimmed.isEmpty &&
      (destinationLatitude == null || destinationLongitude == null)) {
    return false;
  }

  final destination = destinationLatitude != null && destinationLongitude != null
      ? '${destinationLongitude.toStringAsFixed(6)},${destinationLatitude.toStringAsFixed(6)}'
      : Uri.encodeComponent(trimmed);

  final origin = originLatitude != null && originLongitude != null
      ? '${originLongitude.toStringAsFixed(6)},${originLatitude.toStringAsFixed(6)}'
      : '-';

  final modePath = switch (mode) {
    NaverDirectionsMode.car => 'car',
    NaverDirectionsMode.transit => 'transit',
    NaverDirectionsMode.walk => 'walk',
  };

  final url =
      'https://map.naver.com/v5/directions/$origin/$destination/-/$modePath';
  web.window.open(url, '_blank');
  return true;
}

Future<bool> openMapsSearch({
  required String query,
  double? latitude,
  double? longitude,
}) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty && latitude == null) return false;

  final path = latitude != null && longitude != null
      ? '$trimmed/${longitude.toStringAsFixed(6)},${latitude.toStringAsFixed(6)}'
      : Uri.encodeComponent(trimmed);
  final url = 'https://map.naver.com/v5/search/$path';
  web.window.open(url, '_blank');
  return true;
}

String mapsSearchCopiedMessage(String query) =>
    '「$query」주소를 복사했습니다. 지도 앱에서 붙여넣어 길찾기를 이용해 주세요.';
