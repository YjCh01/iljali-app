import 'package:map/core/session/auth_session.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/features/corporate/data/repositories/company_bonus_ledger_repository.dart';
import 'package:map/features/corporate/data/repositories/push_wallet_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/premium_partnership_tier.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_wallet_load_outcome.dart';
import 'package:map/features/corporate/domain/entities/recruitment_product_kind.dart';

/// PUSH·거점 지갑 — 로드·구매·소진
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
    return (await loadWalletDetailed(profile)).wallet;
  }

  Future<PushWalletLoadOutcome> loadWalletDetailed(
    CorporateMemberProfile profile,
  ) async {
    final repo = await _repositoryFuture;
    final ledger = await _bonusLedgerFuture;
    var wallet = profile.pushWallet ?? await repo.load(profile.companyKey);
    wallet = _sanitizeUnpurchasedCredits(profile, wallet);
    var grantedSignupBonus = false;
    var grantedVerificationBonus = false;

    final bonusAlreadyClaimed =
        await ledger.isSignupBonusClaimed(profile.companyKey);
    final needsSignupBonus = wallet.signupBonusRemaining == 0 &&
        wallet.packageCredits == 0 &&
        wallet.locationSlotsFromPackages == 0 &&
        !bonusAlreadyClaimed;

    if (needsSignupBonus) {
      final granted = await ledger.tryClaimSignupBonus(profile.companyKey);
      if (granted) {
        grantedSignupBonus = true;
        wallet = wallet.copyWith(
          packageCredits:
              wallet.packageCredits + PushPackageCatalog.signupBonusPushes,
          locationSlotsFromPackages: wallet.locationSlotsFromPackages +
              PushPackageCatalog.signupBonusPushes,
          lifetimePackagesPurchased: wallet.lifetimePackagesPurchased +
              PushPackageCatalog.signupBonusPushes,
        );
      }
    } else if (wallet.locationSlotsFromPackages == 0 &&
        wallet.packageCredits == 0) {
      wallet = _migrateLegacySubscription(profile, wallet);
    }

    final canGrantVerificationBonus =
        profile.verificationStatus == BusinessVerificationStatus.verified &&
            !await ledger.isVerificationBonusClaimed(profile.companyKey);
    if (canGrantVerificationBonus) {
      final granted =
          await ledger.tryClaimVerificationBonus(profile.companyKey);
      if (granted) {
        grantedVerificationBonus = true;
        wallet = wallet.copyWith(
          packageCredits: wallet.packageCredits +
              PushPackageCatalog.verificationBonusPushes,
          locationSlotsFromPackages: wallet.locationSlotsFromPackages +
              PushPackageCatalog.verificationBonusPushes,
          lifetimePackagesPurchased: wallet.lifetimePackagesPurchased +
              PushPackageCatalog.verificationBonusPushes,
        );
      }
    }

    if (wallet.locationSlotsFromPackages != wallet.packageCredits) {
      wallet = wallet.copyWith(
        locationSlotsFromPackages: wallet.packageCredits,
      );
    }

    if (profile.pushWallet == null ||
        profile.pushWallet!.signupBonusRemaining !=
            wallet.signupBonusRemaining ||
        profile.pushWallet!.packageCredits != wallet.packageCredits ||
        profile.pushWallet!.locationSlotsFromPackages !=
            wallet.locationSlotsFromPackages) {
      await _persist(profile, wallet);
    }
    return PushWalletLoadOutcome(
      wallet: wallet,
      grantedSignupBonus: grantedSignupBonus,
      grantedVerificationBonus: grantedVerificationBonus,
    );
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
    final qty = offer.supportsQuantitySelector ? quantity.clamp(1, 99) : 1;
    final credits = offer.packageCount * qty;

    final updated = switch (offer.kind) {
      RecruitmentProductKind.exposureOnly => wallet.copyWith(
          packageCredits: wallet.packageCredits + credits,
          locationSlotsFromPackages:
              wallet.locationSlotsFromPackages + credits,
          lifetimePackagesPurchased: wallet.lifetimePackagesPurchased + credits,
        ),
      RecruitmentProductKind.exposureWithPush => wallet.copyWith(
          exposurePushBundleCredits:
              wallet.exposurePushBundleCredits + credits,
          lifetimePackagesPurchased: wallet.lifetimePackagesPurchased + credits,
        ),
      RecruitmentProductKind.pushOnly => wallet.copyWith(
          pushTicketCredits: wallet.pushTicketCredits + credits,
          lifetimePackagesPurchased: wallet.lifetimePackagesPurchased + credits,
        ),
    };
    await _persist(profile, updated);
    return updated;
  }

  Future<PushConsumeResult> tryConsumePush(
    CorporateMemberProfile profile,
  ) async {
    return tryConsumeRecruitmentCredit(profile);
  }

  /// 근무지·모집지역 PUSH — 일자리 알림핀 1회
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
      '일자리 알림핀이 부족합니다. 구매하면 즉시 충전됩니다.',
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
              '일자리 알림핀이 부족합니다. (필요 ${count}회 · 사용 ${consumed}회)',
        );
      }
      consumed++;
      current = AuthSession.instance.currentUser?.corporateProfile ?? current;
    }
    return PushMultiConsumeResult.success(consumed: consumed);
  }

  /// 노출+PUSH 번들 1회 — 알림핀/정류장 활성화와 해당 위치 PUSH 1회
  Future<PushConsumeResult> tryConsumeExposurePushBundle(
    CorporateMemberProfile profile,
  ) async {
    final wallet = await loadWallet(profile);
    if (wallet.exposurePushBundleCredits > 0) {
      final updated = wallet.copyWith(
        exposurePushBundleCredits: wallet.exposurePushBundleCredits - 1,
      );
      await _persist(profile, updated);
      return const PushConsumeResult(
        success: true,
        source: PushConsumeSource.packageCredit,
        radiusMeters: PushPackageCatalog.packagePushRadiusM,
      );
    }
    return PushConsumeResult.fail(
      '노출+PUSH 이용권이 없습니다. '
      '${PushPackageCatalog.krwSuffix(PushPackageCatalog.exposureWithPushUnitPriceKrw)} 상품을 구매해 주세요.',
    );
  }

  /// PUSH 알림권 1회 소진 — 알림핀·정류장 1곳 · 1회 발송
  Future<PushConsumeResult> tryConsumePushTicket(
    CorporateMemberProfile profile,
  ) async {
    final wallet = await loadWallet(profile);
    if (wallet.pushTicketCredits > 0) {
      final updated = wallet.copyWith(
        pushTicketCredits: wallet.pushTicketCredits - 1,
      );
      await _persist(profile, updated);
      return const PushConsumeResult(
        success: true,
        source: PushConsumeSource.packageCredit,
        radiusMeters: PushPackageCatalog.packagePushRadiusM,
      );
    }
    return PushConsumeResult.fail(
      'PUSH 알림권이 없습니다. ${PushTicketCatalog.unitPriceLabel} 결제 후 발송할 수 있습니다.',
    );
  }

  Future<void> addPushTicketPurchase(
    CorporateMemberProfile profile, {
    int count = 1,
  }) async {
    if (count <= 0) return;
    final wallet = await loadWallet(profile);
    final updated = wallet.copyWith(
      pushTicketCredits: wallet.pushTicketCredits + count,
    );
    await _persist(profile, updated);
  }

  /// 노출 이용권 충전 — 결제 권한자 결제 완료 후 채용 담당자가 활성화에 사용
  Future<void> addExposureCredits(
    CorporateMemberProfile profile, {
    required int count,
  }) async {
    if (count <= 0) return;
    final wallet = await loadWallet(profile);
    final updated = wallet.copyWith(
      packageCredits: wallet.packageCredits + count,
      locationSlotsFromPackages: wallet.locationSlotsFromPackages + count,
      lifetimePackagesPurchased: wallet.lifetimePackagesPurchased + count,
    );
    await _persist(profile, updated);
  }

  /// 모집지역 삭제 시 — 사용하지 않은 일자리 알림핀 1회 복원
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

  static String _dayKey([DateTime? date]) {
    final d = date ?? DateTime.now();
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String walletSummary(EmployerPushWallet wallet) {
    return '노출 ${wallet.packageCredits}회 · '
        '노출+PUSH ${wallet.exposurePushBundleCredits}회 · '
        'PUSH ${wallet.pushTicketCredits}회 · '
        '노출 범위 ${wallet.totalLocationSlots}곳';
  }

  /// 추가PUSH 버튼 — 사용 가능 일자리 알림핀
  static String availablePushCreditsLabel(EmployerPushWallet wallet) =>
      '보유 ${wallet.availablePushCredits}회';
}
