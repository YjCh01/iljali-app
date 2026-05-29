import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

enum ExtraPushDisableReason {
  none,
  noExposureSettings,
  noRadius,
  creditsExhausted,
}

/// 공고 카드 — 지원자 모집하기 버튼 활성/문구
class ExtraPushAvailability {
  const ExtraPushAvailability({
    required this.enabled,
    required this.subtitle,
    required this.reason,
  });

  final bool enabled;
  final String subtitle;
  final ExtraPushDisableReason reason;

  bool get suggestsPurchase =>
      reason == ExtraPushDisableReason.creditsExhausted;

  bool get needsExposureSetup =>
      reason == ExtraPushDisableReason.noExposureSettings ||
      reason == ExtraPushDisableReason.noRadius;

  bool get canDispatchRecruit =>
      reason == ExtraPushDisableReason.none;

  String buttonLabel({String recruitLabel = '모집하기'}) {
    if (needsExposureSetup) return '모집지역 설정';
    if (reason == ExtraPushDisableReason.creditsExhausted) {
      return '지역 푸시권 충전';
    }
    return recruitLabel;
  }

  static ExtraPushAvailability resolve({
    required CorporateJobPost post,
    EmployerPushWallet? wallet,
  }) {
    final settings = post.notificationSettings;
    if (settings?.hasConfiguredBase != true) {
      final pkg = wallet?.packageRecruitCredits;
      final dailyFree = wallet?.dailyFreePostingAvailable ?? false;
      final subtitle = pkg != null && pkg > 0
          ? '지역 푸시권 $pkg회 · 노출 범위 미설정'
          : dailyFree
              ? '근무지 무료 푸시 1회/일 · 노출 범위 미설정'
              : '노출 범위 미설정 · 설정 필요';
      return ExtraPushAvailability(
        enabled: false,
        reason: ExtraPushDisableReason.noExposureSettings,
        subtitle: subtitle,
      );
    }

    final tier = settings!.primaryBase?.radiusTier;
    if (tier == null || tier == PushRadiusTier.radius0km) {
      return const ExtraPushAvailability(
        enabled: false,
        reason: ExtraPushDisableReason.noRadius,
        subtitle: '노출 반경 없음 · 설정 필요',
      );
    }

    if (wallet != null &&
        settings.basePoints.length >
            PushWalletCreditPolicy.effectiveMaxExposurePoints(
              wallet: wallet,
              currentPointsLength: settings.basePoints.length,
            )) {
      final maxPoints = PushWalletCreditPolicy.effectiveMaxExposurePoints(
        wallet: wallet,
        currentPointsLength: settings.basePoints.length,
      );
      return ExtraPushAvailability(
        enabled: false,
        reason: ExtraPushDisableReason.creditsExhausted,
        subtitle:
            '노출 ${settings.basePoints.length}곳 · 설정 가능 $maxPoints곳 · 모집지역 수정 필요',
      );
    }

    final dispatchCost = wallet == null
        ? null
        : PushWalletCreditPolicy.quickRecruitDispatchCost(
            settings: settings,
            wallet: wallet,
          );

    if (wallet != null && dispatchCost != null) {
      if (dispatchCost.packageCreditsRequired > 0 &&
          wallet.packageCredits < dispatchCost.packageCreditsRequired) {
        return ExtraPushAvailability(
          enabled: false,
          reason: ExtraPushDisableReason.creditsExhausted,
          subtitle: dispatchCost.recruitmentZones > 0
              ? '모집지역 ${dispatchCost.recruitmentZones}곳 · '
                  '지역 푸시권 ${dispatchCost.packageCreditsRequired}회 필요'
              : '지역 푸시권 ${dispatchCost.packageCreditsRequired}회 필요',
        );
      }
      if (dispatchCost.packageCreditsRequired == 0 &&
          !wallet.dailyFreePostingAvailable &&
          dispatchCost.recruitmentZones == 0) {
        return const ExtraPushAvailability(
          enabled: false,
          reason: ExtraPushDisableReason.creditsExhausted,
          subtitle: '근무지 무료 푸시 소진 · 지역 푸시권 구매',
        );
      }
    } else if (wallet != null && !wallet.hasUsablePush) {
      return const ExtraPushAvailability(
        enabled: false,
        reason: ExtraPushDisableReason.creditsExhausted,
        subtitle: '근무지 무료 푸시 소진 · 지역 푸시권 구매',
      );
    }

    if (wallet == null) {
      return const ExtraPushAvailability(
        enabled: true,
        reason: ExtraPushDisableReason.none,
        subtitle: '발송 확인 중',
      );
    }

    final detail = wallet.recruitCreditsDetailLabel;
    return ExtraPushAvailability(
      enabled: true,
      reason: ExtraPushDisableReason.none,
      subtitle: detail,
    );
  }

}
