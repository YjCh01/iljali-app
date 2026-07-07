import 'package:web/web.dart' as web;

import 'package:map/core/utils/naver_directions_url.dart';

export 'package:map/core/utils/naver_directions_url.dart'
    show NaverDirectionsMode;

Future<bool> openNaverDirections({
  required String destinationLabel,
  double? destinationLatitude,
  double? destinationLongitude,
  double? originLatitude,
  double? originLongitude,
  String? originLabel,
  NaverDirectionsMode mode = NaverDirectionsMode.car,
}) async {
  try {
    final url = buildNaverDirectionsUrl(
      destinationLabel: destinationLabel,
      destinationLatitude: destinationLatitude,
      destinationLongitude: destinationLongitude,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      originLabel: originLabel,
      mode: mode,
    );
    web.window.open(url, '_blank');
    return true;
  } on ArgumentError {
    return false;
  }
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
