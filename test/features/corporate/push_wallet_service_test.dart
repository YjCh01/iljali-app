import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/business_verification_status.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/auth_user.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/data/repositories/company_bonus_ledger_repository.dart';
import 'package:map/features/corporate/data/repositories/push_wallet_repository.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadWallet grants signup bonus as package credits', () async {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '9998887776',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '1234',
      pushWallet: EmployerPushWallet(),
    );

    await AuthSession.instance.signIn(
      AuthUser(
        name: '테스트',
        email: 'test@example.com',
        memberType: MemberType.corporate,
        corporateProfile: profile,
      ),
    );

    final ledger = await CompanyBonusLedgerRepository.create();
    final walletRepo = await PushWalletRepository.create();
    final service = PushWalletService(
      repository: walletRepo,
      bonusLedger: ledger,
    );

    final wallet = await service.loadWallet(profile);

    expect(wallet.signupBonusRemaining, 0);
    expect(wallet.packageCredits, PushPackageCatalog.signupBonusPushes);
    expect(wallet.availablePushCredits, PushPackageCatalog.signupBonusPushes);
    expect(
      wallet.jobPostRegistrationQuotaMax,
      PushPackageCatalog.signupBonusPushes,
    );
    expect(
      AuthSession
          .instance.currentUser?.corporateProfile?.pushWallet?.packageCredits,
      PushPackageCatalog.signupBonusPushes,
    );
  });

  test('loadWallet grants verification bonus once after verification',
      () async {
    const profile = CorporateMemberProfile(
      companyName: '검증회사',
      businessRegistrationNumber: '1231231231',
      department: '채용',
      contactPersonName: '검증담당',
      handlerCode: '2222',
      verificationStatus: BusinessVerificationStatus.verified,
      pushWallet: EmployerPushWallet(),
    );
    await AuthSession.instance.signIn(
      AuthUser(
        name: '검증',
        email: 'verified@example.com',
        memberType: MemberType.corporate,
        corporateProfile: profile,
      ),
    );
    final service = PushWalletService(
      repository: await PushWalletRepository.create(),
      bonusLedger: await CompanyBonusLedgerRepository.create(),
    );

    final first = await service.loadWallet(profile);
    expect(
      first.packageCredits,
      PushPackageCatalog.signupBonusPushes +
          PushPackageCatalog.verificationBonusPushes,
    );
    final second = await service.loadWallet(
      AuthSession.instance.currentUser!.corporateProfile!,
    );
    expect(second.packageCredits, first.packageCredits);
  });

  test('loadWallet strips orphan package credits for new accounts', () async {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '1112223334',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '1234',
      pushWallet: EmployerPushWallet(
        packageCredits: 1,
        locationSlotsFromPackages: 1,
        signupBonusRemaining: PushPackageCatalog.signupBonusPushes,
      ),
    );

    await AuthSession.instance.signIn(
      AuthUser(
        name: '테스트',
        email: 'orphan@example.com',
        memberType: MemberType.corporate,
        corporateProfile: profile,
      ),
    );

    final ledger = await CompanyBonusLedgerRepository.create();
    await ledger.tryClaimSignupBonus(profile.companyKey);

    final walletRepo = await PushWalletRepository.create();
    final service = PushWalletService(
      repository: walletRepo,
      bonusLedger: ledger,
    );

    final wallet = await service.loadWallet(profile);

    expect(wallet.packageCredits, 0);
    expect(wallet.locationSlotsFromPackages, 0);
    expect(wallet.availablePushCredits, 0);
    expect(wallet.jobPostRegistrationQuotaMax, 0);
  });

  test('jobPostRegistrationQuotaMax equals package credits only', () {
    const wallet = EmployerPushWallet(
      packageCredits: 3,
    );

    expect(wallet.availablePushCredits, 3);
    expect(wallet.jobPostRegistrationQuotaMax, 3);
  });

  test('addPurchase applies single package quantity to wallet', () async {
    const profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '5556667778',
      department: '채용',
      contactPersonName: '담당',
      handlerCode: '1234',
      pushWallet: EmployerPushWallet(),
    );

    await AuthSession.instance.signIn(
      AuthUser(
        name: '테스트',
        email: 'qty@example.com',
        memberType: MemberType.corporate,
        corporateProfile: profile,
      ),
    );

    final service = PushWalletService(
      repository: await PushWalletRepository.create(),
      bonusLedger: await CompanyBonusLedgerRepository.create(),
    );

    final single = PushPackageCatalog.allOffers.first;
    final wallet = await service.addPurchase(
      profile: profile,
      offer: single,
      quantity: 3,
    );

    expect(wallet.packageCredits, PushPackageCatalog.signupBonusPushes + 3);
    expect(
      wallet.locationSlotsFromPackages,
      PushPackageCatalog.signupBonusPushes + 3,
    );
    expect(wallet.lifetimePackagesPurchased,
        PushPackageCatalog.signupBonusPushes + 3);
  });
}
