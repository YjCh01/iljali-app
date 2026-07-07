enum NaverDirectionsMode { car, transit, walk }

String buildNaverDirectionsUrl({
  required String destinationLabel,
  double? destinationLatitude,
  double? destinationLongitude,
  double? originLatitude,
  double? originLongitude,
  String? originLabel,
  NaverDirectionsMode mode = NaverDirectionsMode.walk,
}) {
  final trimmedDest = destinationLabel.trim();
  if (trimmedDest.isEmpty &&
      (destinationLatitude == null || destinationLongitude == null)) {
    throw ArgumentError('destination is required');
  }

  final destination = destinationLatitude != null && destinationLongitude != null
      ? '${destinationLongitude.toStringAsFixed(6)},${destinationLatitude.toStringAsFixed(6)}'
      : Uri.encodeComponent(trimmedDest);

  final origin = originLatitude != null && originLongitude != null
      ? '${originLongitude.toStringAsFixed(6)},${originLatitude.toStringAsFixed(6)}'
      : (originLabel?.trim().isNotEmpty == true
          ? Uri.encodeComponent(originLabel!.trim())
          : '-');

  final modePath = switch (mode) {
    NaverDirectionsMode.car => 'car',
    NaverDirectionsMode.transit => 'transit',
    NaverDirectionsMode.walk => 'walk',
  };

  return 'https://map.naver.com/v5/directions/$origin/$destination/-/$modePath';
}
