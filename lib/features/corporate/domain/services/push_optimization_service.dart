import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/push_plan_enforcement.dart';
import 'package:map/features/corporate/domain/utils/push_reach_estimator.dart';

/// 푸시 반경·거점·발송 시각 AI 추천 (MVP — 로컬 이력 기반, 1km 고정)
class PushOptimizationRecommendation {
  const PushOptimizationRecommendation({
    required this.suggestedRadius,
    required this.suggestedBaseCount,
    required this.suggestedSendHour,
    required this.expectedReach,
    required this.reason,
    required this.confidencePercent,
  });

  /// 항상 1km — 반경 확대 대신 거점 추가(패키지)로 도달 범위 확장
  final PushRadiusTier suggestedRadius;
  /// 추천 거점 수 (기본 거점 포함, 최소 1)
  final int suggestedBaseCount;
  final int suggestedSendHour;
  final int expectedReach;
  final String reason;
  final int confidencePercent;

  String get sendTimeLabel {
    final h = suggestedSendHour.clamp(0, 23);
    return '${h.toString().padLeft(2, '0')}:00';
  }

  String get headlineLabel {
    final baseLabel = suggestedBaseCount <= 1
        ? '기본 노출 범위'
        : '노출 범위 $suggestedBaseCount곳';
    return '1km · $baseLabel · 약 $expectedReach명 · $sendTimeLabel 발송';
  }
}

class PushOptimizationService {
  Future<PushOptimizationRecommendation> recommend({
    required String companyKey,
    PushRadiusTier? currentRadius,
  }) async {
    final repo = await LocalHiringRepository.create();
    final apps = (await repo.fetchAll())
        .where((a) => a.companyKey == null || a.companyKey == companyKey)
        .toList();

    var checkIns = 0;
    var applications = apps.length;
    final hourCounts = List.filled(24, 0);

    for (final app in apps) {
      hourCounts[app.appliedAt.hour]++;
      if (app.status == HiringApplicationStatus.checkedIn ||
          app.status == HiringApplicationStatus.commissionPaid) {
        checkIns++;
      }
    }

    var bestHour = 7;
    var maxHourCount = 0;
    for (var h = 5; h <= 11; h++) {
      if (hourCounts[h] > maxHourCount) {
        maxHourCount = hourCounts[h];
        bestHour = h;
      }
    }

    const radius = PushRadiusTier.standardFree1km;
    int suggestedBaseCount;
    String reason;
    var confidence = 55;

    final conversion =
        applications > 0 ? checkIns / applications : 0.0;
    final perBaseReach = PushReachEstimator.estimateRecruitmentRights(1);

    if (applications < 3) {
      suggestedBaseCount = 3;
      reason =
          '패키지로 더 넓은 지역, 더 많은 지원자에게 공고 알림을 전송해 보세요.';
      confidence = 45;
    } else if (conversion < 0.15) {
      suggestedBaseCount = 2;
      reason =
          '출근 전환율 ${(conversion * 100).toStringAsFixed(0)}%입니다. 1km 반경에 공고 노출 범위를 추가해 후보 풀을 넓혀 보세요.';
      confidence = 72;
    } else if (conversion >= 0.35) {
      suggestedBaseCount = 1;
      reason =
          '전환율 ${(conversion * 100).toStringAsFixed(0)}%로 양호합니다. 기본 노출 범위 1km로 효율적으로 운영하세요.';
      confidence = 78;
    } else {
      suggestedBaseCount = 2;
      reason =
          '1km 반경에 공고 노출 범위 1~2곳을 추가하면 지원·출근 균형이 좋아집니다. 패키지로 노출·모집을 확장할 수 있습니다.';
      confidence = 65;
    }

    if (currentRadius != null &&
        PushPlanEnforcement.clampRadius(currentRadius) == radius) {
      reason = '$reason (현재 반경과 일치)';
      confidence = (confidence + 5).clamp(0, 95);
    }

    if (maxHourCount > 0) {
      reason = '$reason · 지원 피크 ${bestHour}시 전후 발송 권장';
      confidence = (confidence + 8).clamp(0, 95);
    }

    return PushOptimizationRecommendation(
      suggestedRadius: radius,
      suggestedBaseCount: suggestedBaseCount,
      suggestedSendHour: bestHour,
      expectedReach: perBaseReach * suggestedBaseCount,
      reason: reason,
      confidencePercent: confidence,
    );
  }
}
