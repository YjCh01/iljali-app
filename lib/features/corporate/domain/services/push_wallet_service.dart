import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/repositories/company_bonus_ledger_repository.dart';
import 'package:map/features/corporate/data/repositories/push_wallet_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

/// 푸시·거점 지갑 — 로드·구매·소진
class PushWalletService {
  PushWalletService({
    PushWalletRepository? repository,
    CompanyBonusLedgerRepository? bonusLedger,
  })  : _repositoryFuture = repository != null
            ? Future.value(repository)
            : PushWalletRepository.create(),
        _bonusLedgerFuture = bonusLedger != null
            ? Future.value(bonusLedger)
            : CompanyBonusLedgerRepository.create();

  final Future<PushWalletRepository> _repositoryFuture;
  final Future<CompanyBonusLedgerRepository> _bonusLedgerFuture;

  Future<EmployerPushWallet> loadWallet(CorporateMemberProfile profile) async {
    final repo = await _repositoryFuture;
    final ledger = await _bonusLedgerFuture;
    var wallet = profile.pushWallet ?? await repo.load(profile.companyKey);
    wallet = _sanitizeUnpurchasedCredits(profile, wallet);

    final bonusAlreadyClaimed =
        await ledger.isSignupBonusClaimed(profile.companyKey);
    final needsSignupBonus = wallet.signupBonusRemaining == 0 &&
        wallet.packageCredits == 0 &&
        wallet.locationSlotsFromPackages == 0 &&
        !bonusAlreadyClaimed;

    if (needsSignupBonus) {
      final granted = await ledger.tryClaimSignupBonus(profile.companyKey);
      if (granted) {
        wallet = wallet.copyWith(
          signupBonusRemaining: PushPackageCatalog.signupBonusPushes,
          signupBonusExpiresAt: DateTime.now().add(
            const Duration(days: PushPackageCatalog.signupBonusValidDays),
          ),
        );
      }
    } else if (wallet.signupBonusRemaining ==
            PushPackageCatalog.signupBonusPushes &&
        wallet.locationSlotsFromPackages == 0 &&
        wallet.packageCredits == 0) {
      wallet = _migrateLegacySubscription(profile, wallet);
    }

    if (wallet.locationSlotsFromPackages != wallet.packageCredits) {
      wallet = wallet.copyWith(
        locationSlotsFromPackages: wallet.packageCredits,
      );
    }

    if (profile.pushWallet == null ||
        profile.pushWallet!.signupBonusRemaining != wallet.signupBonusRemaining ||
        profile.pushWallet!.packageCredits != wallet.packageCredits ||
        profile.pushWallet!.locationSlotsFromPackages !=
            wallet.locationSlotsFromPackages) {
      await _persist(profile, wallet);
    }
    return wallet;
  }

  EmployerPushWallet _migrateLegacySubscription(
    CorporateMemberProfile profile,
    EmployerPushWallet wallet,
  ) {
    if (!profile.hasLegacyPaidSubscription) return wallet;
    final bonusCredits = switch (profile.partnershipTier) {
      PremiumPartnershipTier.starter => 10,
      PremiumPartnershipTier.growth => 30,
      PremiumPartnershipTier.enterprise => 50,
      _ => 5,
    };
    return wallet.copyWith(
      packageCredits: wallet.packageCredits + bonusCredits,
      locationSlotsFromPackages:
          wallet.locationSlotsFromPackages + (bonusCredits ~/ 5),
    );
  }

  /// 패키지 미구매·레거시 아닌 계정 — 잘못 쌓인 패키지 크레딧·노출 슬롯 제거
  EmployerPushWallet _sanitizeUnpurchasedCredits(
    CorporateMemberProfile profile,
    EmployerPushWallet wallet,
  ) {
    if (profile.hasLegacyPaidSubscription) return wallet;
    if (wallet.lifetimePackagesPurchased > 0) return wallet;

    var sanitized = wallet;
    if (sanitized.packageCredits > 0) {
      sanitized = sanitized.copyWith(packageCredits: 0);
    }
    if (sanitized.locationSlotsFromPackages > 0) {
      sanitized = sanitized.copyWith(locationSlotsFromPackages: 0);
    }
    return sanitized;
  }

  Future<EmployerPushWallet> addPurchase({
    required CorporateMemberProfile profile,
    required PushPackageBundleOffer offer,
    int quantity = 1,
  }) async {
    final wallet = await loadWallet(profile);
    final qty = offer.id == PushPackageCatalog.singlePackageId
        ? quantity.clamp(1, 99)
        : 1;
    final credits = offer.packageCount * qty;
    final updated = wallet.copyWith(
      packageCredits: wallet.packageCredits + credits,
      locationSlotsFromPackages: wallet.packageCredits + credits,
      lifetimePackagesPurchased:
          wallet.lifetimePackagesPurchased + credits,
      purchased100PackBundle:
          wallet.purchased100PackBundle || offer.id == 'pack_100',
    );
    await _persist(profile, updated);
    return updated;
  }

  Future<PushConsumeResult> tryConsumePush(
    CorporateMemberProfile profile,
  ) async {
    final wallet = await loadWallet(profile);
    final today = _dayKey();

    if (wallet.lastFreePushDayKey != today) {
      final updated = wallet.copyWith(lastFreePushDayKey: today);
      await _persist(profile, updated);
      return PushConsumeResult(
        success: true,
        source: PushConsumeSource.dailyFree,
        radiusMeters: PushPackageCatalog.freePushRadiusM,
      );
    }

    final bonus = _effectiveBonus(wallet);
    if (bonus > 0) {
      final updated = wallet.copyWith(
        signupBonusRemaining: wallet.signupBonusRemaining - 1,
      );
      await _persist(profile, updated);
      return PushConsumeResult(
        success: true,
        source: PushConsumeSource.signupBonus,
        radiusMeters: PushPackageCatalog.freePushRadiusM,
      );
    }

    if (wallet.packageCredits > 0) {
      final updated = wallet.copyWith(
        packageCredits: wallet.packageCredits - 1,
      );
      await _persist(profile, updated);
      return PushConsumeResult(
        success: true,
        source: PushConsumeSource.packageCredit,
        radiusMeters: PushPackageCatalog.packagePushRadiusM,
      );
    }

    return const PushConsumeResult.fail(
      '지역 푸시권이 없습니다. 지역 푸시권을 구매해 주세요.',
    );
  }

  /// 근무지 푸시 — 당일 무료 1회만
  Future<PushConsumeResult> tryConsumeDailyFreeWorkplacePush(
    CorporateMemberProfile profile,
  ) async {
    final wallet = await loadWallet(profile);
    final today = _dayKey();
    if (wallet.lastFreePushDayKey == today) {
      return const PushConsumeResult.fail(
        '오늘 무료 근무지 푸시를 이미 사용했습니다.',
      );
    }
    final updated = wallet.copyWith(lastFreePushDayKey: today);
    await _persist(profile, updated);
    return PushConsumeResult(
      success: true,
      source: PushConsumeSource.dailyFree,
      radiusMeters: PushPackageCatalog.freePushRadiusM,
    );
  }

  /// 모집지역 푸시 — 패키지 발송권만 (일일 무료·보너스 사용 안 함)
  Future<PushConsumeResult> tryConsumeRecruitmentCredit(
    CorporateMemberProfile profile,
  ) async {
    final wallet = await loadWallet(profile);
    if (wallet.packageCredits > 0) {
      final nextCredits = wallet.packageCredits - 1;
      final updated = wallet.copyWith(
        packageCredits: nextCredits,
        locationSlotsFromPackages: nextCredits,
      );
      await _persist(profile, updated);
      return PushConsumeResult(
        success: true,
        source: PushConsumeSource.packageCredit,
        radiusMeters: PushPackageCatalog.packagePushRadiusM,
      );
    }
    return const PushConsumeResult.fail(
      '지역 푸시권이 부족합니다. 구매하면 즉시 충전됩니다.',
    );
  }

  Future<PushMultiConsumeResult> tryConsumeRecruitmentCredits(
    CorporateMemberProfile profile,
    int count,
  ) async {
    if (count <= 0) {
      return const PushMultiConsumeResult.success(consumed: 0);
    }
    var current = profile;
    var consumed = 0;
    for (var i = 0; i < count; i++) {
      final result = await tryConsumeRecruitmentCredit(current);
      if (!result.success) {
        return PushMultiConsumeResult.fail(
          result.message ??
              '모집지역 푸시 이용권이 부족합니다. (필요 ${count}회 · 사용 ${consumed}회)',
        );
      }
      consumed++;
      current = AuthSession.instance.currentUser?.corporateProfile ?? current;
    }
    return PushMultiConsumeResult.success(consumed: consumed);
  }

  /// 모집지역 삭제 시 — 사용하지 않은 지역 푸시권 1회 복원
  Future<void> refundRecruitmentCredit(
    CorporateMemberProfile profile, {
    int count = 1,
  }) async {
    if (count <= 0) return;
    final wallet = await loadWallet(profile);
    final updated = wallet.copyWith(
      packageCredits: wallet.packageCredits + count,
      locationSlotsFromPackages: wallet.packageCredits + count,
    );
    await _persist(profile, updated);
  }

  Future<int> maxLocationSlots(CorporateMemberProfile profile) async {
    final wallet = await loadWallet(profile);
    return wallet.totalLocationSlots;
  }

  Future<void> _persist(
    CorporateMemberProfile profile,
    EmployerPushWallet wallet,
  ) async {
    final repo = await _repositoryFuture;
    await repo.save(profile.companyKey, wallet);
    final updatedProfile = profile.copyWith(pushWallet: wallet);
    await AuthSession.instance.updateCorporateProfile(updatedProfile);
  }

  int _effectiveBonus(EmployerPushWallet wallet) {
    if (wallet.signupBonusRemaining <= 0) return 0;
    final expires = wallet.signupBonusExpiresAt;
    if (expires != null && DateTime.now().isAfter(expires)) return 0;
    return wallet.signupBonusRemaining;
  }

  static String _dayKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String walletSummary(EmployerPushWallet wallet) {
    final freeToday = wallet.dailyFreePostingAvailable ? 1 : 0;
    return '지역 푸시권 ${wallet.packageCredits}회 · '
        '노출 범위 ${wallet.totalLocationSlots}곳 · '
        '오늘 무료 $freeToday/${PushPackageCatalog.dailyFreePush}';
  }

  /// 추가푸시 버튼 — 사용 가능 횟수 (무료·보너스·패키지 합산)
  static String availablePushCreditsLabel(EmployerPushWallet wallet) =>
      '보유 ${wallet.availablePushCredits}회';

  static int _effectiveBonusStatic(EmployerPushWallet wallet) {
    if (wallet.signupBonusRemaining <= 0) return 0;
    final expires = wallet.signupBonusExpiresAt;
    if (expires != null && DateTime.now().isAfter(expires)) return 0;
    return wallet.signupBonusRemaining;
  }
}
