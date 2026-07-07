  /// 합격 구직자 — 기업 노선 공유 수신 동의 (회사당 1건)
class SeekerShuttleRouteShareConsent {
  const SeekerShuttleRouteShareConsent({
    required this.seekerEmail,
    required this.companyKey,
    required this.companyName,
    required this.optedIn,
    required this.updatedAt,
    this.towerParticipationOffered = false,
    this.towerParticipationConsented = false,
    this.offerPending = false,
    this.applicationId,
  });

  final String seekerEmail;
  final String companyKey;
  final String companyName;

  /// true: 노선 공유 수신 · false: 자차·도보 등으로 거절
  final bool optedIn;
  final DateTime updatedAt;

  /// 채용 확정 시 셔틀 안내·관제탑 참여 안내를 받았는지
  final bool towerParticipationOffered;

  /// 노선 공유 수신 시 관제탑 프로세스 참여 동의
  final bool towerParticipationConsented;

  /// 채용 확정 후 아직 수락/거절 전
  final bool offerPending;
  final String? applicationId;

  String get storageKey => '${seekerEmail.trim().toLowerCase()}|${companyKey.trim()}';

  Map<String, dynamic> toJson() => {
        'seekerEmail': seekerEmail,
        'companyKey': companyKey,
        'companyName': companyName,
        'optedIn': optedIn,
        'updatedAt': updatedAt.toIso8601String(),
        'towerParticipationOffered': towerParticipationOffered,
        'towerParticipationConsented': towerParticipationConsented,
        'offerPending': offerPending,
        if (applicationId != null) 'applicationId': applicationId,
      };

  factory SeekerShuttleRouteShareConsent.fromJson(Map<String, dynamic> json) {
    return SeekerShuttleRouteShareConsent(
      seekerEmail: json['seekerEmail'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      companyName: json['companyName'] as String? ?? '',
      optedIn: json['optedIn'] as bool? ?? false,
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.now(),
      towerParticipationOffered:
          json['towerParticipationOffered'] as bool? ?? false,
      towerParticipationConsented:
          json['towerParticipationConsented'] as bool? ?? false,
      offerPending: json['offerPending'] as bool? ?? false,
      applicationId: json['applicationId'] as String?,
    );
  }

  SeekerShuttleRouteShareConsent copyWith({
    bool? optedIn,
    bool? towerParticipationOffered,
    bool? towerParticipationConsented,
    bool? offerPending,
    String? applicationId,
    DateTime? updatedAt,
  }) {
    return SeekerShuttleRouteShareConsent(
      seekerEmail: seekerEmail,
      companyKey: companyKey,
      companyName: companyName,
      optedIn: optedIn ?? this.optedIn,
      updatedAt: updatedAt ?? this.updatedAt,
      towerParticipationOffered:
          towerParticipationOffered ?? this.towerParticipationOffered,
      towerParticipationConsented:
          towerParticipationConsented ?? this.towerParticipationConsented,
      offerPending: offerPending ?? this.offerPending,
      applicationId: applicationId ?? this.applicationId,
    );
  }
}
