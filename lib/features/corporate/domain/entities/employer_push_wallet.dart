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

  int get availablePushCredits {
    final bonus = _effectiveSignupBonus;
    return packageCredits + bonus + _dailyFreeRemaining;
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

  /// 공고 등록(푸시) 표시용 최대 — 보너스 5장 풀 + 당일 1장 + 패키지
  int get jobPostRegistrationQuotaMax {
    final signupCap = _effectiveSignupBonus > 0
        ? PushPackageCatalog.signupBonusPushes
        : 0;
    return packageCredits + signupCap + PushPackageCatalog.dailyFreePush;
  }

  int get jobPostRegistrationQuotaRemaining => availablePushCredits;

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
