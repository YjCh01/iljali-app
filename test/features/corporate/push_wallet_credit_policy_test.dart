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



  test('job post card credits separate daily free from package', () {

    const wallet = EmployerPushWallet(

      signupBonusRemaining: PushPackageCatalog.signupBonusPushes,

    );

    final display = PushWalletCreditPolicy.jobPostCardCredits(wallet: wallet);

    expect(display.packageCredits, 0);

    expect(display.dailyFreeAvailable, isTrue);

    expect(display.showChip, isFalse);

    expect(display.chipLabel, isEmpty);

    expect(

      display.accountFreePushHint,

      '근무지 1km · 오늘 무료 푸시 1회 남음',

    );

  });



  test('job post card chip shows package label only for paid credits', () {

    final now = DateTime.now();

    final todayKey =

        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final wallet = EmployerPushWallet(

      packageCredits: 2,

      lastFreePushDayKey: todayKey,

    );

    final display = PushWalletCreditPolicy.jobPostCardCredits(wallet: wallet);

    expect(display.chipLabel, '지역 푸시권 2회 보유중');

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

    expect(summary.billableCredits, 2);

  });



  test('extra push single zone without edits costs one recruitment credit', () {

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

      0,

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

    expect(wallet.availablePushCredits, 4);

    expect(wallet.paidRecruitCreditsAvailable, 3);

  });



  test('registrationCost is always free regardless of daily free state', () {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
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
    final wallet = EmployerPushWallet(
      locationSlotsFromPackages: 1,
      lastFreePushDayKey: todayKey,
    );
    final cost = PushWalletCreditPolicy.registrationCost(
      settings: settings,
      wallet: wallet,
    );
    expect(cost.packageCreditsRequired, 0);
    expect(cost.usesDailyFreeWorkplace, isFalse);
    expect(
      PushWalletCreditPolicy.canAffordRegistration(
        settings: settings,
        wallet: wallet,
      ),
      isTrue,
    );
  });



  test('two regional tickets not required for registration', () {

    final now = DateTime.now();

    final todayKey =

        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final settings = JobPostNotificationSettings(

      basePoints: [

        _point('w'),

        _point('r1'),

        _point('r2'),

      ],

    );

    final wallet = EmployerPushWallet(
      packageCredits: 2,
      locationSlotsFromPackages: 2,
      lastFreePushDayKey: todayKey,
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

  test('quick recruit dispatch requires one regional ticket per zone', () {
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
    expect(cost.packageCreditsRequired, 12);
    expect(
      PushWalletCreditPolicy.canAffordQuickRecruit(
        settings: settings,
        wallet: wallet,
      ),
      isFalse,
    );
  });

  test('registration is free; dispatch costs regional tickets', () {
    final now = DateTime.now();
    final todayKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final settings = JobPostNotificationSettings(
      basePoints: [
        _point('w'),
        _point('r1'),
        _point('r2'),
      ],
    );
    final wallet = EmployerPushWallet(
      packageCredits: 2,
      locationSlotsFromPackages: 2,
      lastFreePushDayKey: todayKey,
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
      2,
    );
  });

}
