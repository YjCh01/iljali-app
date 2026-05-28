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
      locationSlotsFromPackages:
          wallet.locationSlotsFromPackages + credits,
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
      '알림 크레딧이 없습니다. 공고 노출·모집 패키지를 구매해 주세요.',
    );
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
    final freeToday = wallet.lastFreePushDayKey == _dayKey() ? 0 : 1;
    return '패키지 ${wallet.packageCredits}회 · '
        '노출 범위 ${wallet.totalLocationSlots}곳 · '
        '오늘 무료 $freeToday/${PushPackageCatalog.dailyFreePush} · '
        '보너스 ${_effectiveBonusStatic(wallet)}회';
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
