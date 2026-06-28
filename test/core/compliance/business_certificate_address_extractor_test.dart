import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/compliance/services/business_certificate_address_extractor.dart';

void main() {
  group('BusinessCertificateAddressExtractor', () {
    test('extracts address after 사업장 소재지 label', () {
      final address = BusinessCertificateAddressExtractor.fromOcrLines([
        '사업자등록증',
        '상호 (주)라인헬스케어',
        '사업장 소재지',
        '경기도 성남시 분당구 판교역로 235',
      ]);
      expect(address, '경기도 성남시 분당구 판교역로 235');
    });

    test('extracts inline address after colon', () {
      final address = BusinessCertificateAddressExtractor.fromOcrLines([
        '본점 소재지 : 서울특별시 강남구 테헤란로 152',
      ]);
      expect(address, '서울특별시 강남구 테헤란로 152');
    });

    test('looksLikeKoreanRoadAddress rejects short strings', () {
      expect(
        BusinessCertificateAddressExtractor.looksLikeKoreanRoadAddress('서울'),
        isFalse,
      );
      expect(
        BusinessCertificateAddressExtractor.looksLikeKoreanRoadAddress(
          '서울특별시 강남구 테헤란로 152',
        ),
        isTrue,
      );
    });
  });
}
