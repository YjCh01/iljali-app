import 'dart:math' as math;

import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_ranking_context.dart';

/// 클러스터(핀 뭉치) 목록 상위 노출 — 다중 요소 랭킹
///
/// **원칙:** 돈 많이 낸 순이 아니라, 구직자에게 실제 가치 있는 순 +
/// 적절한 유료(알림핀) 부스트.
///
/// | 요소 | 가중치 | 설명 |
/// |------|--------|------|
/// | 성과 | 35% | 지원·관심(프록시: applicantCount) |
/// | 신선도 | 20% | 최근 12~48시간 등록 우대 |
/// | 알림핀 부스트 | 15% | 보라 > 고시급 > 일반 (과도한 상위 고정 방지) |
/// | 품질·신뢰 | 15% | 사업자 검증·공고 정보 완성도 |
/// | 맞춤 | 10% | 구직자 위치와의 거리 |
/// | 만료 임박 | 5% | 곧 마감 공고 소폭 가중 |
abstract final class JobMapPinRankingService {
  static const performanceWeight = 0.35;
  static const recencyWeight = 0.20;
  static const sponsoredWeight = 0.15;
  static const qualityWeight = 0.15;
  static const personalizationWeight = 0.10;
  static const expiryWeight = 0.05;

  static List<JobMapPin> rankClusterPins(
    List<JobMapPin> pins, {
    JobMapPinRankingContext context = const JobMapPinRankingContext(),
    DateTime? now,
  }) {
    final active = pins.where((pin) => !pin.isClosedGhost).toList();
    final ghosts = pins.where((pin) => pin.isClosedGhost).toList();
    if (active.length <= 1) return [...active, ...ghosts];
    final clock = now ?? DateTime.now();
    final scored = active
        .map(
          (pin) => (
            pin: pin,
            score: compositeScore(pin, context: context, now: clock),
          ),
        )
        .toList();
    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.pin.post.postedAt.compareTo(a.pin.post.postedAt);
    });
    return [...scored.map((e) => e.pin), ...ghosts];
  }

  static double compositeScore(
    JobMapPin pin, {
    JobMapPinRankingContext context = const JobMapPinRankingContext(),
    required DateTime now,
  }) {
    return performanceWeight * _performanceScore(pin) +
        recencyWeight * _recencyScore(pin, now) +
        sponsoredWeight * _sponsoredScore(pin) +
        qualityWeight * _qualityScore(pin, context) +
        personalizationWeight * _personalizationScore(pin, context) +
        expiryWeight * _expiryUrgencyScore(pin, now);
  }

  /// 지원·관심 활동 (서버 CTR/저장 수로 교체 예정)
  static double _performanceScore(JobMapPin pin) {
    final applicants = pin.post.applicantCount;
    return (applicants / 20).clamp(0.0, 1.0);
  }

  static double _recencyScore(JobMapPin pin, DateTime now) {
    final hours = now.difference(pin.post.postedAt).inHours;
    if (hours <= 12) return 1.0;
    if (hours <= 24) return 0.85;
    if (hours <= 48) return 0.65;
    if (hours <= 168) return 0.4;
    return 0.2;
  }

  /// 알림핀 등급 — 유료 부스트는 제한적(15%)
  static double _sponsoredScore(JobMapPin pin) {
    return switch (pin.displayTier) {
      JobMapPinDisplayTier.packageActive => 1.0,
      JobMapPinDisplayTier.premiumWage => 0.45,
      JobMapPinDisplayTier.standard => 0.25,
      JobMapPinDisplayTier.closedGhost => 0.0,
    };
  }

  static double _qualityScore(
    JobMapPin pin,
    JobMapPinRankingContext context,
  ) {
    var score = 0.0;
    final profile = pin.post.registeredBy;
    if (profile?.verificationStatus == BusinessVerificationStatus.verified) {
      score += 0.55;
    }
    if (pin.post.jobDescription.trim().isNotEmpty) score += 0.15;
    if (pin.post.summary.trim().isNotEmpty) score += 0.1;
    if (pin.post.hourlyWage.trim().isNotEmpty) score += 0.1;
    if (pin.post.workSchedule.trim().isNotEmpty) score += 0.1;
    if (pin.post.showsShuttleRouteOverlay) score += 0.12;
    if (context.preferShuttle && pin.post.showsShuttleRouteOverlay) {
      score += 0.35;
    }
    return score.clamp(0.0, 1.0);
  }

  static double _personalizationScore(
    JobMapPin pin,
    JobMapPinRankingContext context,
  ) {
    if (!context.hasSeekerLocation) return 0.5;
    final km = _haversineKm(
      context.seekerLatitude!,
      context.seekerLongitude!,
      pin.latitude,
      pin.longitude,
    );
    if (km <= 1) return 1.0;
    if (km <= 3) return 0.75;
    if (km <= 5) return 0.5;
    if (km <= 10) return 0.3;
    return 0.15;
  }

  static double _expiryUrgencyScore(JobMapPin pin, DateTime now) {
    final expires = pin.post.expiresAt;
    if (expires == null) return 0.3;
    final hoursLeft = expires.difference(now).inHours;
    if (hoursLeft <= 0) return 0;
    if (hoursLeft <= 24) return 1.0;
    if (hoursLeft <= 48) return 0.6;
    return 0.2;
  }

  static double _haversineKm(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRad(lat2 - lat1);
    final dLng = _toRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRad(lat1)) *
            math.cos(_toRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return earthRadiusKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _toRad(double deg) => deg * math.pi / 180;
}
