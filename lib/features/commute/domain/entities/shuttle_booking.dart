/// 구직자 셔틀 탑승 예약 (로컬 MVP)
class ShuttleBooking {
  const ShuttleBooking({
    required this.id,
    required this.seekerEmail,
    required this.postId,
    required this.routeId,
    required this.stopId,
    required this.stopLabel,
    required this.pickupTime,
    required this.shiftDate,
    required this.createdAt,
  });

  final String id;
  final String seekerEmail;
  final String postId;
  final String routeId;
  final String stopId;
  final String stopLabel;

  /// 정류장 탑승 시간 (예: 07:30)
  final String pickupTime;

  /// 근무일 ISO (yyyy-MM-dd)
  final String shiftDate;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'seekerEmail': seekerEmail,
        'postId': postId,
        'routeId': routeId,
        'stopId': stopId,
        'stopLabel': stopLabel,
        'pickupTime': pickupTime,
        'shiftDate': shiftDate,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ShuttleBooking.fromJson(Map<String, dynamic> json) {
    return ShuttleBooking(
      id: json['id'] as String? ?? '',
      seekerEmail: json['seekerEmail'] as String? ?? '',
      postId: json['postId'] as String? ?? '',
      routeId: json['routeId'] as String? ?? '',
      stopId: json['stopId'] as String? ?? '',
      stopLabel: json['stopLabel'] as String? ?? '',
      pickupTime: json['pickupTime'] as String? ?? '',
      shiftDate: json['shiftDate'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
