import 'package:flutter_test/flutter_test.dart';

import 'package:map/core/geo/geo_coordinate.dart';

import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

import 'package:map/features/corporate/domain/utils/job_post_validity.dart';

import 'package:map/features/corporate/domain/utils/push_wallet_credit_policy.dart';

PushNotificationBasePoint _point(String id, {double lat = 37.5}) {
  return PushNotificationBasePoint(
    id: id,
    coordinate: GeoCoordinate(latitude: lat, longitude: 127.0),
    addressLabel: id,
  );
}

void main() {
  test('configure remaining add slots requires slot and push ticket', () {
    expect(
      PushWalletCreditPolicy.configureRemainingAddSlots(
        slotRemaining: 0,
        availableCredits: 14,
        recruitZoneCount: 12,
      ),
      0,
    );
    expect(
      PushWalletCreditPolicy.configureRemainingAddSlots(
        slotRemaining: 5,
        availableCredits: 14,
        recruitZoneCount: 12,
      ),
      5,
    );
    expect(
      PushWalletCreditPolicy.configureRemainingAddSlots(
        slotRemaining: 10,
        availableCredits: 2,
        recruitZoneCount: 0,
      ),
      2,
    );
  });

  test('configure preview remaining add slots ignores wallet credits', () {
    const cap = 10;
    expect(
      PushWalletCreditPolicy.configurePreviewRemainingAddSlots(
        pointsLength: 1,
        previewRecruitmentPinCap: cap,
      ),
      cap,
    );
    expect(
      PushWalletCreditPolicy.configurePreviewRemainingAddSlots(
        pointsLength: 6,
        previewRecruitmentPinCap: cap,
      ),
      5,
    );
    expect(
      PushWalletCreditPolicy.configurePreviewRemainingAddSlots(
        pointsLength: 11,
        previewRecruitmentPinCap: cap,
      ),
      0,
    );
  });

  test('configure mode max points uses wallet credits and existing zones', () {
    const walletWithZones = EmployerPushWallet(packageCredits: 0);
    expect(
      PushWalletCreditPolicy.configureModeMaxPoints(
        pointsLength: 13,
        availableCredits: 0,
        wallet: walletWithZones,
      ),
      13,
    );

    expect(
      PushWalletCreditPolicy.configureModeMaxPoints(
        pointsLength: 1,
        availableCredits: 6,
        wallet: null,
      ),
      7,
    );

    const walletWithCredits = EmployerPushWallet(packageCredits: 16);
    expect(
      PushWalletCreditPolicy.configureModeMaxPoints(
        pointsLength: 4,
        availableCredits: 16,
        wallet: walletWithCredits,
      ),
      20,
    );
  });

  test('effective max exposure points matches zones plus remaining credits', () {
    const wallet = EmployerPushWallet(packageCredits: 3);
    expect(
      PushWalletCreditPolicy.effectiveMaxExposurePoints(
        wallet: wallet,
        currentPointsLength: 1,
      ),
      4,
    );

    const spentWallet = EmployerPushWallet(packageCredits: 0);
    expect(
      PushWalletCreditPolicy.effectiveMaxExposurePoints(
        wallet: spentWallet,
        currentPointsLength: 3,
      ),
      3,
    );
  });

  test('job post card display credits are package-only', () {
    const wallet = EmployerPushWallet(
      packageCredits: 14,
      locationSlotsFromPackages: 12,
    );
    final settings = JobPostNotificationSettings(
      basePoints: [
        _point('w'),
        for (var i = 1; i <= 12; i++) _point('r$i'),
      ],
    );
    expect(
      PushWalletCreditPolicy.jobPostCardDisplayCredits(
        wallet: wallet,
        settings: settings,
      ),
      14,
    );
  });

  test('job post card credits show package only', () {
    const wallet = EmployerPushWallet(
      signupBonusRemaining: PushPackageCatalog.signupBonusPushes,
    );
    final display = PushWalletCreditPolicy.jobPostCardCredits(wallet: wallet);
    expect(display.packageCredits, 0);
    expect(display.showChip, isFalse);
    expect(display.chipLabel, isEmpty);
  });

  test('job post card chip shows package label only for paid credits', () {
    const wallet = EmployerPushWallet(packageCredits: 2);
    final display = PushWalletCreditPolicy.jobPostCardCredits(wallet: wallet);
    expect(display.chipLabel, '일자리 알림핀 2회 보유중');
  });

  test('configure preview keeps posting rights regardless of zones', () {
    expect(
      PushWalletCreditPolicy.configurePreviewRemainingCredits(
        availableCredits: 14,
        recruitZoneCount: 12,
      ),
      14,
    );
    expect(
      PushWalletCreditPolicy.configurePreviewRemainingCredits(
        availableCredits: 3,
        recruitZoneCount: 5,
      ),
      3,
    );
  });

  test('registration recruit zone count is display-only', () {
    final settings = JobPostNotificationSettings(
      basePoints: [_point('w'), _point('r1'), _point('r2')],
    );
    expect(
      PushWalletCreditPolicy.registrationRecruitZoneCount(settings),
      2,
    );
  });

  test('free post registration requires zero paid credits', () {
    final settings = JobPostNotificationSettings(
      basePoints: [_point('w')],
    );
    const wallet = EmployerPushWallet();
    final cost = PushWalletCreditPolicy.registrationCost(
      settings: settings,
      wallet: wallet,
    );
    expect(cost.packageCreditsRequired, 0);
  });

  test('extra push with zone edits bills all final recruitment zones', () {
    final before = [_point('w'), _point('r1'), _point('r2')];
    final after = [_point('w'), _point('r1'), _point('r3', lat: 37.6)];

    final summary = PushWalletCreditPolicy.extraPushCreditsRequired(
      before: before,
      after: after,
    );

    expect(summary.structureChanged, isTrue);
    expect(summary.billableCredits, 1);
  });

  test('extra push single zone without edits costs one regional credit', () {
    final points = [_point('w'), _point('r1')];
    expect(
      PushWalletCreditPolicy.extraPushBillableCredits(
        before: points,
        after: points,
        activePointIndex: 1,
      ),
      1,
    );
    expect(
      PushWalletCreditPolicy.extraPushBillableCredits(
        before: points,
        after: points,
        activePointIndex: 0,
      ),
      1,
    );
  });

  test('post expires end of next day 23:59:59', () {
    final posted = DateTime(2026, 5, 28, 10, 30);
    final expires = JobPostValidity.expiresAtFromRegistration(posted);
    expect(expires, DateTime(2026, 5, 29, 23, 59, 59));
    expect(
      JobPostValidity.isExpired(expires, DateTime(2026, 5, 29, 23, 59, 58)),
      isFalse,
    );
    expect(
      JobPostValidity.isExpired(expires, DateTime(2026, 5, 30, 0, 0, 0)),
      isTrue,
    );
  });

  test('paid recruit credits are package-only', () {
    const wallet = EmployerPushWallet(
      signupBonusRemaining: PushPackageCatalog.signupBonusPushes,
      packageCredits: 3,
    );
    expect(wallet.availablePushCredits, 3);
    expect(wallet.paidRecruitCreditsAvailable, 3);
  });

  test('registrationCost is always free', () {
    final settings = JobPostNotificationSettings(
      basePoints: [
        PushNotificationBasePoint(
          id: 'w',
          coordinate: GeoCoordinate(latitude: 37.5, longitude: 127.0),
          addressLabel: '근무지',
          radiusTier: PushRadiusTier.standardFree1km,
        ),
        PushNotificationBasePoint(
          id: 'r1',
          coordinate: GeoCoordinate(latitude: 37.51, longitude: 127.01),
          addressLabel: '모집1',
          radiusTier: PushRadiusTier.standard1km,
        ),
      ],
    );
    const wallet = EmployerPushWallet(locationSlotsFromPackages: 1);
    final cost = PushWalletCreditPolicy.registrationCost(
      settings: settings,
      wallet: wallet,
    );
    expect(cost.packageCreditsRequired, 0);
    expect(
      PushWalletCreditPolicy.canAffordRegistration(
        settings: settings,
        wallet: wallet,
      ),
      isTrue,
    );
  });

  test('two regional tickets not required for registration', () {
    final settings = JobPostNotificationSettings(
      basePoints: [
        _point('w'),
        _point('r1'),
        _point('r2'),
      ],
    );
    const wallet = EmployerPushWallet(
      packageCredits: 2,
      locationSlotsFromPackages: 2,
    );
    final cost = PushWalletCreditPolicy.registrationCost(
      settings: settings,
      wallet: wallet,
    );
    expect(cost.packageCreditsRequired, 0);
    expect(
      PushWalletCreditPolicy.canAffordRegistration(
        settings: settings,
        wallet: wallet,
      ),
      isTrue,
    );
  });

  test('quick recruit dispatch requires workplace plus regional tickets', () {
    final settings = JobPostNotificationSettings(
      basePoints: [
        _point('w'),
        for (var i = 1; i <= 12; i++) _point('r$i'),
      ],
    );
    const wallet = EmployerPushWallet(packageCredits: 1);
    final cost = PushWalletCreditPolicy.quickRecruitDispatchCost(
      settings: settings,
      wallet: wallet,
    );
    expect(cost.recruitmentZones, 12);
    expect(cost.recruitmentCreditsRequired, 12);
    expect(cost.workplaceCreditsRequired, 1);
    expect(cost.packageCreditsRequired, 13);
    expect(cost.canAffordFull(wallet), isFalse);
    expect(
      PushWalletCreditPolicy.canAffordQuickRecruit(
        settings: settings,
        wallet: wallet,
      ),
      isFalse,
    );
  });

  test('quick recruit full dispatch costs workplace plus regional tickets', () {
    final settings = JobPostNotificationSettings(
      basePoints: [_point('w'), _point('r1'), _point('r2')],
    );
    const wallet = EmployerPushWallet(packageCredits: 3);
    final cost = PushWalletCreditPolicy.quickRecruitDispatchCost(
      settings: settings,
      wallet: wallet,
    );
    expect(cost.recruitmentCreditsRequired, 2);
    expect(cost.workplaceCreditsRequired, 1);
    expect(cost.packageCreditsRequired, 3);
    expect(cost.canAffordFull(wallet), isTrue);
  });

  test('registration is free; dispatch costs regional tickets', () {
    final settings = JobPostNotificationSettings(
      basePoints: [
        _point('w'),
        _point('r1'),
        _point('r2'),
      ],
    );
    const wallet = EmployerPushWallet(
      packageCredits: 2,
      locationSlotsFromPackages: 2,
    );
    expect(
      PushWalletCreditPolicy.registrationCost(
        settings: settings,
        wallet: wallet,
      ).packageCreditsRequired,
      0,
    );
    expect(
      PushWalletCreditPolicy.quickRecruitDispatchCost(
        settings: settings,
        wallet: wallet,
      ).packageCreditsRequired,
      3,
    );
  });
}
