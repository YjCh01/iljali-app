/// 구직자 — 회사·노선별 통근 정류장 선택 (내 버스 탭)
class SeekerShuttleCommutePreference {
  const SeekerShuttleCommutePreference({
    required this.seekerEmail,
    required this.companyKey,
    required this.companyName,
    required this.routeId,
    required this.routeName,
    required this.stopId,
    required this.stopLabel,
    required this.pickupTime,
    required this.updatedAt,
  });

  final String seekerEmail;
  final String companyKey;
  final String companyName;
  final String routeId;
  final String routeName;
  final String stopId;
  final String stopLabel;
  final String pickupTime;
  final DateTime updatedAt;

  String get storageKey => '$seekerEmail|$companyKey';

  Map<String, dynamic> toJson() => {
        'seekerEmail': seekerEmail,
        'companyKey': companyKey,
        'companyName': companyName,
        'routeId': routeId,
        'routeName': routeName,
        'stopId': stopId,
        'stopLabel': stopLabel,
        'pickupTime': pickupTime,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory SeekerShuttleCommutePreference.fromJson(Map<String, dynamic> json) {
    return SeekerShuttleCommutePreference(
      seekerEmail: json['seekerEmail'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      routeName: json['routeName'] as String? ?? '',
      stopId: json['stopId'] as String? ?? '',
      stopLabel: json['stopLabel'] as String? ?? '',
      pickupTime: json['pickupTime'] as String? ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
