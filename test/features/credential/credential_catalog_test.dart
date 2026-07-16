import 'package:flutter_test/flutter_test.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/credential/domain/entities/credential_category.dart';

void main() {
  setUp(() {
    // 각 테스트를 오프라인 기본 15종으로 리셋 (정적 캐시가 테스트 간 공유되므로).
    CredentialCatalog.resetToOfflineDefaultsForTest();
  });

  test('defaults to the 15 built-in offline credentials', () {
    expect(CredentialCatalog.all.length, 15);
    expect(CredentialCatalog.findById('health_certificate'), isNotNull);
  });

  test('overrideFromServer replaces the cache with parsed server items', () {
    CredentialCatalog.overrideFromServer([
      {
        'id': 'new_cred',
        'label': '신규 자격증',
        'category': 'foodService',
        'aliases': ['신규', '테스트'],
        'requires_photo': false,
        'summary': '서버에서만 추가된 항목',
        'guide_document_id': null,
      },
    ]);

    expect(CredentialCatalog.all.length, 1);
    final item = CredentialCatalog.findById('new_cred');
    expect(item, isNotNull);
    expect(item!.label, '신규 자격증');
    expect(item.category, CredentialCategory.foodService);
    expect(item.requiresPhoto, isFalse);
    expect(item.aliases, contains('테스트'));
  });

  test('overrideFromServer skips malformed items and ignores empty lists', () {
    CredentialCatalog.overrideFromServer([
      {'id': 'missing_label'},
      {'id': 'bad_category', 'label': 'x', 'category': 'not_a_real_category'},
    ]);
    // 전부 파싱 실패 — 기존(기본) 캐시 유지
    expect(CredentialCatalog.all.length, 15);

    // 빈 목록 응답도 기존 캐시를 비우지 않고 유지해야 함(네트워크 이상으로
    // 전체 자격증이 사라지는 사고 방지).
    CredentialCatalog.overrideFromServer(const []);
    expect(CredentialCatalog.all.length, 15);
  });
}
