import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';

/// 기업별 PUSH·거점 크레딧 지갑
class EmployerPushWallet {
  const EmployerPushWallet({
    this.packageCredits = 0,
    this.exposurePushBundleCredits = 0,
    this.pushTicketCredits = 0,
    this.signupBonusRemaining = 0,
    this.locationSlotsFromPackages = 0,
    this.cashBalanceKrw = 0,
    this.lastFreePushDayKey,
    this.signupBonusExpiresAt,
    this.lifetimePackagesPurchased = 0,
    this.purchased100PackBundle = false,
  });

  final int packageCredits;

  /// 노출+PUSH 번들 — 알림핀/정류장 노출과 해당 위치 700m PUSH 1회
  final int exposurePushBundleCredits;

  /// PUSH 알림권 — 알림핀·정류장 1곳 선택 · PUSH만 (19,900원/회)
  final int pushTicketCredits;
  final int signupBonusRemaining;
  final int locationSlotsFromPackages;

  /// 선충전 보유금 — 결제 시 우선 차감
  final int cashBalanceKrw;

  /// @deprecated Legacy daily-free tracking — no longer used for dispatch.
  final String? lastFreePushDayKey;
  final DateTime? signupBonusExpiresAt;

  /// 누적 패키지 구매 수 (할인·지도 열람 권한 등)
  final int lifetimePackagesPurchased;

  /// 100회 팩 번들 구매 이력 (할인·크레딧만, 핀 색상 혜택 없음)
  final bool purchased100PackBundle;

  int get totalLocationSlots =>
      PushPackageCatalog.baseLocationSlots + locationSlotsFromPackages;

  /// 지원자 모집하기(PUSH) — 일자리 알림핀만
  int get availablePushCredits => packageCredits;

  /// UI용 — 패키지 크레딧만 (유료 구매분)
  int get packageRecruitCredits => packageCredits;

  String get recruitCreditsDetailLabel {
    if (!hasUsablePush) {
      return '일자리 알림핀 0회 · 일자리 알림핀 구매 시 즉시 충전';
    }
    return '일자리 알림핀 $packageCredits';
  }

  bool get hasUsablePush => availablePushCredits > 0;

  bool get hasPushTickets => pushTicketCredits > 0;

  bool get hasExposurePushBundles => exposurePushBundleCredits > 0;

  String get pushTicketDetailLabel {
    if (pushTicketCredits <= 0) {
      return 'PUSH 알림권 0회 · 발송 시 ${PushTicketCatalog.unitPriceLabel}';
    }
    return 'PUSH 알림권 $pushTicketCredits회';
  }

  String get exposurePushBundleDetailLabel {
    if (exposurePushBundleCredits <= 0) {
      return '노출+PUSH 0회 · ${PushPackageCatalog.krwSuffix(PushPackageCatalog.exposureWithPushUnitPriceKrw)}';
    }
    return '노출+PUSH $exposurePushBundleCredits회';
  }

  /// 모집지역·근무지 PUSH — 일자리 알림핀만
  int get paidRecruitCreditsAvailable => packageCredits;

  /// 공고 등록 표시용 — 일자리 알림핀 잔여
  int get jobPostRegistrationQuotaMax => packageCredits;

  int get jobPostRegistrationQuotaRemaining => availablePushCredits;

  bool get hasCashBalance => cashBalanceKrw > 0;

  String get cashBalanceLabel =>
      '${_formatKrw(cashBalanceKrw)}원';

  static String _formatKrw(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }

  EmployerPushWallet copyWith({
    int? packageCredits,
    int? exposurePushBundleCredits,
    int? pushTicketCredits,
    int? signupBonusRemaining,
    int? locationSlotsFromPackages,
    int? cashBalanceKrw,
    String? lastFreePushDayKey,
    DateTime? signupBonusExpiresAt,
    int? lifetimePackagesPurchased,
    bool? purchased100PackBundle,
    bool clearLastFreePushDayKey = false,
  }) {
    return EmployerPushWallet(
      packageCredits: packageCredits ?? this.packageCredits,
      exposurePushBundleCredits:
          exposurePushBundleCredits ?? this.exposurePushBundleCredits,
      pushTicketCredits: pushTicketCredits ?? this.pushTicketCredits,
      signupBonusRemaining: signupBonusRemaining ?? this.signupBonusRemaining,
      locationSlotsFromPackages:
          locationSlotsFromPackages ?? this.locationSlotsFromPackages,
      cashBalanceKrw: cashBalanceKrw ?? this.cashBalanceKrw,
      lastFreePushDayKey: clearLastFreePushDayKey
          ? null
          : (lastFreePushDayKey ?? this.lastFreePushDayKey),
      signupBonusExpiresAt: signupBonusExpiresAt ?? this.signupBonusExpiresAt,
      lifetimePackagesPurchased:
          lifetimePackagesPurchased ?? this.lifetimePackagesPurchased,
      purchased100PackBundle:
          purchased100PackBundle ?? this.purchased100PackBundle,
    );
  }

  Map<String, dynamic> toJson() => {
        'packageCredits': packageCredits,
        'exposurePushBundleCredits': exposurePushBundleCredits,
        'pushTicketCredits': pushTicketCredits,
        'signupBonusRemaining': signupBonusRemaining,
        'locationSlotsFromPackages': locationSlotsFromPackages,
        'cashBalanceKrw': cashBalanceKrw,
        'lastFreePushDayKey': lastFreePushDayKey,
        'signupBonusExpiresAt': signupBonusExpiresAt?.toIso8601String(),
        'lifetimePackagesPurchased': lifetimePackagesPurchased,
        'purchased100PackBundle': purchased100PackBundle,
      };

  factory EmployerPushWallet.fromJson(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return EmployerPushWallet.initial();
    }
    return EmployerPushWallet(
      packageCredits: map['packageCredits'] as int? ?? 0,
      exposurePushBundleCredits:
          map['exposurePushBundleCredits'] as int? ?? 0,
      pushTicketCredits: map['pushTicketCredits'] as int? ?? 0,
      signupBonusRemaining: map['signupBonusRemaining'] as int? ?? 0,
      locationSlotsFromPackages:
          map['locationSlotsFromPackages'] as int? ?? 0,
      cashBalanceKrw: map['cashBalanceKrw'] as int? ?? 0,
      lastFreePushDayKey: map['lastFreePushDayKey'] as String?,
      signupBonusExpiresAt: DateTime.tryParse(
        map['signupBonusExpiresAt'] as String? ?? '',
      ),
      lifetimePackagesPurchased:
          map['lifetimePackagesPurchased'] as int? ?? 0,
      purchased100PackBundle:
          map['purchased100PackBundle'] as bool? ?? false,
    );
  }

  factory EmployerPushWallet.initial() => EmployerPushWallet(
        signupBonusExpiresAt: DateTime.now().add(
          const Duration(days: PushPackageCatalog.signupBonusValidDays),
        ),
        signupBonusRemaining: 0,
      );
}

enum PushConsumeSource {
  signupBonus,
  packageCredit,
}

class PushConsumeResult {
  const PushConsumeResult({
    required this.success,
    this.source,
    this.radiusMeters,
    this.message,
  });

  const PushConsumeResult.fail(this.message)
      : success = false,
        source = null,
        radiusMeters = null;

  final bool success;
  final PushConsumeSource? source;
  final int? radiusMeters;
  final String? message;

  bool get usedPackageCredit => source == PushConsumeSource.packageCredit;
}

class PushMultiConsumeResult {
  const PushMultiConsumeResult({
    required this.success,
    required this.consumed,
    this.message,
  });

  const PushMultiConsumeResult.success({required this.consumed})
      : success = true,
        message = null;

  const PushMultiConsumeResult.fail(this.message)
      : success = false,
        consumed = 0;

  final bool success;
  final int consumed;
  final String? message;
}
