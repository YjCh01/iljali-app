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
}
