/// 통근 관제탑 알리미 동의 — 셔틀 프로세스 참여자
enum SeekerCommuteTowerRole {
  shuttleParticipant,
  firstStopAlerter,
  designatedDriver,
}

extension SeekerCommuteTowerRoleX on SeekerCommuteTowerRole {
  String get storageValue => switch (this) {
        SeekerCommuteTowerRole.shuttleParticipant => 'shuttle_participant',
        SeekerCommuteTowerRole.firstStopAlerter => 'first_stop_alerter',
        SeekerCommuteTowerRole.designatedDriver => 'designated_driver',
      };

  static SeekerCommuteTowerRole? tryParse(String? raw) {
    switch (raw) {
      case 'shuttle_participant':
        return SeekerCommuteTowerRole.shuttleParticipant;
      case 'first_stop_alerter':
        return SeekerCommuteTowerRole.firstStopAlerter;
      case 'designated_driver':
        return SeekerCommuteTowerRole.designatedDriver;
      default:
        return null;
    }
  }
}

class SeekerCommuteTowerConsent {
  const SeekerCommuteTowerConsent({
    required this.seekerEmail,
    required this.companyKey,
    required this.routeId,
    required this.stopId,
    required this.role,
    required this.consentedAt,
    this.trackingEnabled = false,
    this.trackingEnabledAt,
  });

  final String seekerEmail;
  final String companyKey;
  final String routeId;
  final String stopId;
  final SeekerCommuteTowerRole role;
  final DateTime consentedAt;
  final bool trackingEnabled;
  final DateTime? trackingEnabledAt;

  String get storageKey =>
      '${seekerEmail.trim().toLowerCase()}|${companyKey.trim()}|${routeId.trim()}';

  Map<String, dynamic> toJson() => {
        'seekerEmail': seekerEmail,
        'companyKey': companyKey,
        'routeId': routeId,
        'stopId': stopId,
        'role': role.storageValue,
        'consentedAt': consentedAt.toIso8601String(),
        'trackingEnabled': trackingEnabled,
        if (trackingEnabledAt != null)
          'trackingEnabledAt': trackingEnabledAt!.toIso8601String(),
      };

  factory SeekerCommuteTowerConsent.fromJson(Map<String, dynamic> json) {
    return SeekerCommuteTowerConsent(
      seekerEmail: json['seekerEmail'] as String? ?? '',
      companyKey: json['companyKey'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      stopId: json['stopId'] as String? ?? '',
      role: SeekerCommuteTowerRoleX.tryParse(json['role'] as String?) ??
          SeekerCommuteTowerRole.shuttleParticipant,
      consentedAt: DateTime.tryParse(json['consentedAt'] as String? ?? '') ??
          DateTime.now(),
      trackingEnabled: json['trackingEnabled'] as bool? ?? false,
      trackingEnabledAt:
          DateTime.tryParse(json['trackingEnabledAt'] as String? ?? ''),
    );
  }

  SeekerCommuteTowerConsent copyWith({
    bool? trackingEnabled,
    DateTime? trackingEnabledAt,
  }) {
    return SeekerCommuteTowerConsent(
      seekerEmail: seekerEmail,
      companyKey: companyKey,
      routeId: routeId,
      stopId: stopId,
      role: role,
      consentedAt: consentedAt,
      trackingEnabled: trackingEnabled ?? this.trackingEnabled,
      trackingEnabledAt: trackingEnabledAt ?? this.trackingEnabledAt,
    );
  }
}
