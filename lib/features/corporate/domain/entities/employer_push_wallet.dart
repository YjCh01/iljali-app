import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

/// 기업별 푸시·거점 크레딧 지갑
class EmployerPushWallet {
  const EmployerPushWallet({
    this.packageCredits = 0,
    this.signupBonusRemaining = 0,
    this.locationSlotsFromPackages = 0,
    this.lastFreePushDayKey,
    this.signupBonusExpiresAt,
    this.lifetimePackagesPurchased = 0,
    this.purchased100PackBundle = false,
  });

  final int packageCredits;
  final int signupBonusRemaining;
  final int locationSlotsFromPackages;
  final String? lastFreePushDayKey;
  final DateTime? signupBonusExpiresAt;

  /// 누적 패키지 구매 수 (100회 팩 프리미엄 핀 판정용)
  final int lifetimePackagesPurchased;

  /// 100회 팩 번들 구매 이력
  final bool purchased100PackBundle;

  /// 100회 팩 구매자 → 모든 공고 노란 프리미엄 핀
  bool get qualifiesForPremiumMapPin =>
      purchased100PackBundle || lifetimePackagesPurchased >= 100;

  int get totalLocationSlots =>
      PushPackageCatalog.baseLocationSlots + locationSlotsFromPackages;

  /// 지원자 모집하기(푸시) — 당일 무료 + 패키지 발송권 (보너스는 등록권으로 사용 안 함)
  int get availablePushCredits {
    return packageCredits + _dailyFreeRemaining;
  }

  /// UI용 — 패키지 크레딧만 (유료 구매분)
  int get packageRecruitCredits => packageCredits;

  String get recruitCreditsDetailLabel {
    if (!hasUsablePush) {
      return '오늘 무료·지역 푸시권 모두 소진 · 지역 푸시권 구매 시 즉시 충전';
    }
    final parts = <String>[];
    if (_dailyFreeRemaining > 0) {
      parts.add('근무지 무료 푸시 1회/일(1km)');
    }
    if (packageCredits > 0) parts.add('지역 푸시권 $packageCredits');
    return parts.join(' · ');
  }

  int get _dailyFreeRemaining {
    if (lastFreePushDayKey == _todayKey()) return 0;
    return PushPackageCatalog.dailyFreePush;
  }

  int get _effectiveSignupBonus {
    if (signupBonusRemaining <= 0) return 0;
    final expires = signupBonusExpiresAt;
    if (expires != null && DateTime.now().isAfter(expires)) return 0;
    return signupBonusRemaining;
  }

  bool get hasUsablePush => availablePushCredits > 0;

  /// 모집지역·유료 근무지 푸시 — 패키지 발송권만 (일일 무료 제외)
  int get paidRecruitCreditsAvailable => packageCredits;

  /// 공고 등록 표시용 — 당일 무료 1 + 패키지 발송권
  int get jobPostRegistrationQuotaMax =>
      packageCredits + PushPackageCatalog.dailyFreePush;

  int get jobPostRegistrationQuotaRemaining => availablePushCredits;

  bool get dailyFreePostingAvailable => _dailyFreeRemaining > 0;

  EmployerPushWallet copyWith({
    int? packageCredits,
    int? signupBonusRemaining,
    int? locationSlotsFromPackages,
    String? lastFreePushDayKey,
    DateTime? signupBonusExpiresAt,
    int? lifetimePackagesPurchased,
    bool? purchased100PackBundle,
    bool clearLastFreePushDayKey = false,
  }) {
    return EmployerPushWallet(
      packageCredits: packageCredits ?? this.packageCredits,
      signupBonusRemaining: signupBonusRemaining ?? this.signupBonusRemaining,
      locationSlotsFromPackages:
          locationSlotsFromPackages ?? this.locationSlotsFromPackages,
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
        'signupBonusRemaining': signupBonusRemaining,
        'locationSlotsFromPackages': locationSlotsFromPackages,
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
      signupBonusRemaining: map['signupBonusRemaining'] as int? ?? 0,
      locationSlotsFromPackages:
          map['locationSlotsFromPackages'] as int? ?? 0,
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

  static String _todayKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}

enum PushConsumeSource {
  dailyFree,
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
