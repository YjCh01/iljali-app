import 'package:flutter_test/flutter_test.dart';

import 'package:map/core/geo/geo_coordinate.dart';

import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';

import 'package:map/features/corporate/domain/utils/extra_push_availability.dart';



PushNotificationBasePoint _workplace() {

  return PushNotificationBasePoint(

    id: 'w',

    coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),

    addressLabel: '근무지',

    radiusTier: PushRadiusTier.standardFree1km,

  );

}



CorporateJobPost _post({JobPostNotificationSettings? settings}) {

  return CorporateJobPost(

    id: 'p1',

    title: 'test',

    warehouseName: '매장',

    hourlyWage: '10,320원',

    workSchedule: '09:00~18:00',

    summary: 'test',

    status: CorporateJobPostStatus.recruiting,

    applicantCount: 0,

    postedAt: DateTime(2026, 5, 28),

    notificationSettings: settings,

  );

}



void main() {

  test('disabled when exposure settings missing', () {

    const wallet = EmployerPushWallet(

      signupBonusRemaining: PushPackageCatalog.signupBonusPushes,

    );

    final availability = ExtraPushAvailability.resolve(

      post: _post(),

      wallet: wallet,

    );

    expect(availability.enabled, isFalse);

    expect(availability.subtitle, contains('노출 범위 미설정'));

    expect(availability.buttonLabel(), '모집지역 설정');

    expect(availability.reason, ExtraPushDisableReason.noExposureSettings);

  });



  test('shows credits when enabled', () {

    const wallet = EmployerPushWallet(

      packageCredits: 2,

    );

    final availability = ExtraPushAvailability.resolve(

      post: _post(

        settings: JobPostNotificationSettings(

          basePoints: [_workplace()],

        ),

      ),

      wallet: wallet,

    );

    expect(availability.enabled, isTrue);

    expect(availability.canDispatchRecruit, isTrue);

    expect(availability.subtitle, contains('근무지 무료'));

    expect(availability.subtitle, contains('지역 푸시권 2'));

  });



  test('shows wallet balance when settings missing but credits remain', () {

    const wallet = EmployerPushWallet(packageCredits: 2);

    final availability = ExtraPushAvailability.resolve(

      post: _post(),

      wallet: wallet,

    );

    expect(availability.subtitle, contains('지역 푸시권 2회'));

  });



  test('disabled when recruitment zones exceed package credits', () {
    const wallet = EmployerPushWallet(
      packageCredits: 1,
      locationSlotsFromPackages: 12,
    );
    final availability = ExtraPushAvailability.resolve(
      post: _post(
        settings: JobPostNotificationSettings(
          basePoints: [
            _workplace(),
            for (var i = 1; i <= 12; i++)
              PushNotificationBasePoint(
                id: 'r$i',
                coordinate: const GeoCoordinate(
                  latitude: 37.5,
                  longitude: 127.0,
                ),
                addressLabel: '모집 $i',
                radiusTier: PushRadiusTier.standard1km,
              ),
          ],
        ),
      ),
      wallet: wallet,
    );
    expect(availability.enabled, isFalse);
    expect(availability.canDispatchRecruit, isFalse);
    expect(availability.subtitle, contains('모집지역 12곳'));
    expect(availability.subtitle, contains('지역 푸시권 12회 필요'));
    expect(availability.buttonLabel(), '지역 푸시권 충전');
  });

  test('disabled when packages insufficient for many recruitment zones', () {
    const wallet = EmployerPushWallet(
      packageCredits: 5,
      locationSlotsFromPackages: 8,
    );
    final availability = ExtraPushAvailability.resolve(
      post: _post(
        settings: JobPostNotificationSettings(
          basePoints: [
            _workplace(),
            for (var i = 1; i <= 8; i++)
              PushNotificationBasePoint(
                id: 'r$i',
                coordinate: const GeoCoordinate(
                  latitude: 37.5,
                  longitude: 127.0,
                ),
                addressLabel: '모집 $i',
                radiusTier: PushRadiusTier.standard1km,
              ),
          ],
        ),
      ),
      wallet: wallet,
    );
    expect(availability.enabled, isFalse);
    expect(availability.subtitle, contains('모집지역 8곳'));
  });



  test('enabled when recruitment zones configured with enough credits', () {

    const wallet = EmployerPushWallet(

      packageCredits: 14,

      locationSlotsFromPackages: 12,

    );

    final availability = ExtraPushAvailability.resolve(

      post: _post(

        settings: JobPostNotificationSettings(

          basePoints: [

            _workplace(),

            for (var i = 1; i <= 12; i++)

              PushNotificationBasePoint(

                id: 'r$i',

                coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),

                addressLabel: '모집 $i',

                radiusTier: PushRadiusTier.standard1km,

              ),

          ],

        ),

      ),

      wallet: wallet,

    );

    expect(availability.enabled, isTrue);

    expect(availability.canDispatchRecruit, isTrue);

    expect(availability.subtitle, contains('지역 푸시권 14'));

  });



  test('disabled when credits exhausted', () {

    final now = DateTime.now();

    final todayKey =

        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final wallet = EmployerPushWallet(

      lastFreePushDayKey: todayKey,

    );

    final availability = ExtraPushAvailability.resolve(

      post: _post(

        settings: JobPostNotificationSettings(

          basePoints: [_workplace()],

        ),

      ),

      wallet: wallet,

    );

    expect(availability.enabled, isFalse);
    expect(availability.subtitle, contains('지역 푸시권 1회 필요'));
  });
}


