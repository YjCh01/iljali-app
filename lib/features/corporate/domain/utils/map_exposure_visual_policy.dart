import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/domain/utils/shuttle_exposure_policy.dart';
import 'package:map/features/corporate/domain/utils/shuttle_route_visibility.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin_display_tier.dart';

/// 지도 노출 — 무료/유료 시각 차별화 정책 (단일 기준)
abstract final class MapExposureVisualPolicy {
  /// 무료 공고 핀 — 회색
  static const freeJobPinColor = Color(0xFF757575);

  /// 근무지(0번) — 무료·미결제 시 회색
  static const freeWorkplacePinColor = Color(0xFF8A8A8A);

  /// 근무지 — 유료 노출 중 보라
  static const paidWorkplacePinColor = Color(0xFF5E35B1);

  /// 일자리 알림핀 기본 — 연보라
  static const defaultRecruitmentPinColor = Color(0xFF9B86F0);

  /// 알림핀·근무지 점선 — 1개부터
  static const recruitmentLinkMinCount = 1;

  /// 셔틀 노선 실선 — 정류장 3곳 이상
  static int get shuttlePolylineMinStops =>
      ShuttleRouteVisibility.polylineMinActivatedStops;

  /// 노출 만료 — 결제일 D+1 23:59:59
  static DateTime exposureExpiresAt(DateTime paidAt) =>
      ShuttleExposurePolicy.expiresAtFromPayment(paidAt);

  static bool isExposureActive(DateTime? paidAt) =>
      ShuttleExposurePolicy.isActive(paidAt);

  static JobMapPinDisplayTier tierForFreePost() =>
      JobMapPinDisplayTier.standard;

  static JobMapPinDisplayTier tierForPaidRecruitmentPin() =>
      JobMapPinDisplayTier.packageActive;

  static String summaryLabel({
    required bool isPaidExposureActive,
    required bool hasRecruitmentPin,
    required bool hasShuttleRoute,
  }) {
    if (!isPaidExposureActive) {
      return '무료 — 근무지·회색 핀만';
    }
    final parts = <String>['유료 노출 중'];
    if (hasRecruitmentPin) parts.add('알림핀+점선');
    if (hasShuttleRoute) parts.add('셔틀노선(3정류장+)');
    return parts.join(' · ');
  }
}
