import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/geo/geo_coordinate.dart';
import 'package:map/core/map/map_initial_center_policy.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/presentation/widgets/push_radius_map_picker.dart';

void main() {
  test('syncPlaceholder prefers workplace then business site', () {
    const workplace = GeoCoordinate(latitude: 37.01, longitude: 127.2);
    const business = GeoCoordinate(latitude: 37.02, longitude: 127.3);

    expect(
      MapInitialCenterPolicy.syncPlaceholder(coordinate: workplace).latitude,
      workplace.latitude,
    );
    expect(
      MapInitialCenterPolicy.syncPlaceholder(
        businessSiteCoordinate: business,
      ).latitude,
      business.latitude,
    );
  });

  test('corporateBusinessSite uses stored head office coordinate', () async {
    const coord = GeoCoordinate(latitude: 36.99, longitude: 127.11);
    final profile = CorporateMemberProfile(
      companyName: '테스트',
      businessRegistrationNumber: '1234567890',
      department: '인사',
      contactPersonName: '홍길동',
      handlerCode: 'AB12CD',
      businessHeadOfficeAddress: '경기 안성시',
      businessHeadOfficeLatitude: coord.latitude,
      businessHeadOfficeLongitude: coord.longitude,
    );

    final resolved =
        await MapInitialCenterPolicy.corporateBusinessSite(profile: profile);
    expect(resolved.latitude, coord.latitude);
    expect(resolved.longitude, coord.longitude);
  });

  test('isFallback detects gangnam demo center', () {
    expect(
      MapInitialCenterPolicy.isFallback(defaultPushMapCenter()),
      isTrue,
    );
    expect(
      MapInitialCenterPolicy.isFallback(
        const GeoCoordinate(latitude: 37.01, longitude: 127.2),
      ),
      isFalse,
    );
  });
}
