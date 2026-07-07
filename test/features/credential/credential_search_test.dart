import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/credential/domain/services/credential_search_service.dart';

void main() {
  test('지게차 검색 시 건설기계조종사·지게차 운전기능사 연관 추천', () {
    final results = CredentialSearchService.search('지게차');
    final ids = results.map((e) => e.id).toSet();
    expect(ids, contains(CredentialCatalog.constructionMachineryLicense.id));
    expect(ids, contains(CredentialCatalog.forkliftOperatorCert.id));
  });

  test('경비 검색 시 신임교육·범죄경력 동의서 추천', () {
    final results = CredentialSearchService.search('경비');
    final ids = results.map((e) => e.id).toSet();
    expect(ids, contains(CredentialCatalog.securityGuardTraining.id));
  });

  test('보건 검색 시 보건증·건설 안전보건교육 둘 다 (식품 먼저)', () {
    final results = CredentialSearchService.search('보건');
    expect(results.length, 2);
    expect(results[0].id, CredentialCatalog.healthCertificate.id);
    expect(results[1].id, CredentialCatalog.constructionSafetyBasic.id);
  });

  test('보건증 검색', () {
    final results = CredentialSearchService.search('보건증');
    expect(results.first.id, CredentialCatalog.healthCertificate.id);
  });
}
