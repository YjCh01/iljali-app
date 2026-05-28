import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/corporate/data/datasources/workplace_address_remote_data_source.dart';

void main() {
  group('WorkplaceAddressRemoteDataSource', () {
    test('parses Juso API row with coordinates', () {
      final address = WorkplaceAddressRemoteDataSource.parseRow({
        'road_address': '서울특별시 강남구 테헤란로 152',
        'jibun_address': '서울특별시 강남구 역삼동 737',
        'dong_name': '역삼동',
        'building_name': '강남파이낸스센터',
        'zip_code': '06236',
        'latitude': 37.5001,
        'longitude': 127.0364,
      });

      expect(address, isNotNull);
      expect(address!.roadAddress, contains('테헤란로'));
      expect(address.jibunAddress, contains('역삼동'));
      expect(address.dongName, '역삼동');
      expect(address.coordinate?.latitude, 37.5001);
    });

    test('returns null for empty road address', () {
      expect(
        WorkplaceAddressRemoteDataSource.parseRow({'road_address': ''}),
        isNull,
      );
    });
  });
}
