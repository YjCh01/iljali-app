import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/entities/push_ticket_catalog.dart';
import 'package:map/features/corporate/domain/utils/extra_push_availability.dart';

CorporateJobPost _post({JobPostNotificationSettings? settings, String? routeId}) {
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
    commuteRouteId: routeId,
  );
}

void main() {
  test('disabled when no targets', () {
    final availability = ExtraPushAvailability.resolve(
      post: _post(),
      wallet: const EmployerPushWallet(),
    );
    expect(availability.enabled, isFalse);
    expect(availability.reason, ExtraPushDisableReason.noTargets);
  });

  test('enabled with workplace target shows push ticket price', () {
    const wallet = EmployerPushWallet(pushTicketCredits: 2);
    final availability = ExtraPushAvailability.resolve(
      post: _post(
        settings: JobPostNotificationSettings(
          basePoints: [
            PushNotificationBasePoint(
              id: 'w',
              coordinate: const GeoCoordinate(latitude: 37.5, longitude: 127.0),
              addressLabel: '본사',
              radiusTier: PushRadiusTier.standardFree1km,
            ),
          ],
        ),
      ),
      wallet: wallet,
    );
    expect(availability.canDispatchRecruit, isTrue);
    expect(availability.recruitButtonCostLabel, PushTicketCatalog.unitPriceLabel);
    expect(availability.subtitle, contains('PUSH 알림권 2회'));
  });

  test('shuttle route alone enables push selection', () {
    final availability = ExtraPushAvailability.resolve(
      post: _post(routeId: 'route-1'),
      wallet: const EmployerPushWallet(),
    );
    expect(availability.canDispatchRecruit, isTrue);
    expect(availability.subtitle, contains('셔틀 정류장'));
  });
}
