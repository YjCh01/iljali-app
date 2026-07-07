/// 실시간 버스 위치 관제 — 파일럿 참여 상태
class BusLocationTowerPilotStatus {
  const BusLocationTowerPilotStatus({
    this.isDesignated = false,
    this.isAuthorizedRider = false,
    this.viewerRole = 'inactive',
    this.enabled = false,
    this.phase = 'inactive',
    this.title = '실시간 버스 위치 관제',
    this.message = '',
    this.locationConsentGranted = false,
    this.companyKey = '',
    this.companyName = '',
    this.routeId = '',
    this.routeName = '',
    this.serviceDate = '',
    this.canShareLocation = false,
    this.canTrackLocation = false,
    this.authorizedRiderCount = 0,
    this.riderStopLabel = '',
    this.riderPickupTime = '',
    this.workStartTime = '',
    this.trackingStoppedReason = '',
    this.todaySession,
    this.chatHint = '',
  });

  final bool isDesignated;
  final bool isAuthorizedRider;
  final String viewerRole;
  final bool enabled;
  final String phase;
  final String title;
  final String message;
  final bool locationConsentGranted;
  final String companyKey;
  final String companyName;
  final String routeId;
  final String routeName;
  final String serviceDate;
  final bool canShareLocation;
  final bool canTrackLocation;
  final int authorizedRiderCount;
  final String riderStopLabel;
  final String riderPickupTime;
  final String workStartTime;
  final String trackingStoppedReason;
  final Map<String, dynamic>? todaySession;
  final String chatHint;

  bool get shouldShowEntry => enabled && (isDesignated || isAuthorizedRider);

  bool get isPreparing =>
      phase == 'preparing' ||
      phase == 'awaiting_location';

  bool get arrivedAtWorkplace =>
      phase == 'arrived_at_workplace' ||
      trackingStoppedReason == 'work_start_arrived' ||
      todaySession?['arrived_at_workplace'] == true;

  bool get hasLiveLocation =>
      !arrivedAtWorkplace &&
      todaySession?['active'] == true &&
      todaySession?['last_latitude'] != null &&
      todaySession?['last_longitude'] != null;

  factory BusLocationTowerPilotStatus.fromJson(Map<String, dynamic> json) {
    return BusLocationTowerPilotStatus(
      isDesignated: json['is_designated'] == true,
      isAuthorizedRider: json['is_authorized_rider'] == true,
      viewerRole: json['viewer_role'] as String? ?? 'inactive',
      enabled: json['enabled'] == true,
      phase: json['phase'] as String? ?? 'inactive',
      title: json['title'] as String? ?? '실시간 버스 위치 관제',
      message: json['message'] as String? ?? '',
      locationConsentGranted: json['location_consent_granted'] == true,
      companyKey: json['company_key'] as String? ?? '',
      companyName: json['company_name'] as String? ?? '',
      routeId: json['route_id'] as String? ?? '',
      routeName: json['route_name'] as String? ?? '',
      serviceDate: json['service_date'] as String? ?? '',
      canShareLocation: json['can_share_location'] == true,
      canTrackLocation: json['can_track_location'] == true,
      authorizedRiderCount: json['authorized_rider_count'] as int? ?? 0,
      riderStopLabel: json['rider_stop_label'] as String? ?? '',
      riderPickupTime: json['rider_pickup_time'] as String? ?? '',
      workStartTime: json['work_start_time'] as String? ?? '',
      trackingStoppedReason: json['tracking_stopped_reason'] as String? ?? '',
      todaySession: json['today_session'] == null
          ? null
          : Map<String, dynamic>.from(json['today_session'] as Map),
      chatHint: json['chat_hint'] as String? ?? '',
    );
  }

  static const inactive = BusLocationTowerPilotStatus();
}
