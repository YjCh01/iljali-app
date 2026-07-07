import 'package:map/features/credential/domain/entities/credential_category.dart';

/// 면허·자격증·교육이수·서류 (표준 DB 항목)
class CredentialDefinition {
  const CredentialDefinition({
    required this.id,
    required this.label,
    required this.category,
    this.aliases = const [],
    this.requiresPhoto = true,
    this.summary,
    this.guideDocumentId,
  });

  final String id;
  final String label;
  final CredentialCategory category;

  /// 검색·연관검색어 (예: 지게차 → 건설기계조종사, 지게차 운전기능사)
  final List<String> aliases;
  final bool requiresPhoto;

  /// 선택 목록 부가 설명 (발급처·용도 등)
  final String? summary;

  /// [LegalDocumentCatalog] id — 전문보기 링크
  final String? guideDocumentId;
}
