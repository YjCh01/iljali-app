/// 구직자 신뢰도 배지
enum SeekerTrustBadge {
  newcomer,
  reliableAttendance,
  noShowFree,
  fastResponder,
  veteran,
}

extension SeekerTrustBadgeX on SeekerTrustBadge {
  String get label => switch (this) {
        SeekerTrustBadge.newcomer => '신규',
        SeekerTrustBadge.reliableAttendance => '출근 인증',
        SeekerTrustBadge.noShowFree => '노쇼 제로',
        SeekerTrustBadge.fastResponder => '빠른 응답',
        SeekerTrustBadge.veteran => '베테랑',
      };

  String get emoji => switch (this) {
        SeekerTrustBadge.newcomer => '🌱',
        SeekerTrustBadge.reliableAttendance => '✅',
        SeekerTrustBadge.noShowFree => '⭐',
        SeekerTrustBadge.fastResponder => '⚡',
        SeekerTrustBadge.veteran => '🏅',
      };
}

class SeekerTrustSummary {
  const SeekerTrustSummary({
    required this.score,
    required this.badges,
    required this.checkInCount,
    required this.noShowCount,
  });

  final int score;
  final List<SeekerTrustBadge> badges;
  final int checkInCount;
  final int noShowCount;
}
