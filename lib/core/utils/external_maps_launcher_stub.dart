import 'package:flutter/services.dart';

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
  await Clipboard.setData(ClipboardData(text: trimmed));
  return false;
}

Future<bool> openMapsSearch({
  required String query,
  double? latitude,
  double? longitude,
}) async {
  final trimmed = query.trim();
  if (trimmed.isEmpty && latitude == null) return false;
  await Clipboard.setData(ClipboardData(text: trimmed));
  return false;
}

String mapsSearchCopiedMessage(String query) =>
    '「$query」주소를 복사했습니다. 지도 앱에서 붙여넣어 길찾기를 이용해 주세요.';
