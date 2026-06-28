import 'package:map/features/credential/domain/entities/credential_category.dart';

/// 면허·자격증·교육이수·서류 (표준 DB 항목)
class CredentialDefinition {
  const CredentialDefinition({
    required this.id,
    required this.label,
    required this.category,
    this.aliases = const [],
    this.requiresPhoto = true,
  });

  final String id;
  final String label;
  final CredentialCategory category;

  /// 검색·연관검색어 (예: 지게차 → 건설기계조종사, 지게차 운전기능사)
  final List<String> aliases;
  final bool requiresPhoto;
}
