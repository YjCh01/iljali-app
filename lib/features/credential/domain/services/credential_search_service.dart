import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/credential/domain/entities/credential_definition.dart';

/// 자격증 검색·연관검색어
abstract final class CredentialSearchService {
  static List<CredentialDefinition> search(
    String query, {
    int limit = 12,
    Set<String> excludeIds = const {},
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    final scored = <_Scored>[];
    for (final def in CredentialCatalog.all) {
      if (excludeIds.contains(def.id)) continue;
      final score = _score(def, q);
      if (score > 0) scored.add(_Scored(def, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.def).toList();
  }

  /// 입력 중 하단 추천 (부분 일치·별칭)
  static List<CredentialDefinition> suggest(
    String query, {
    int limit = 6,
    Set<String> excludeIds = const {},
  }) {
    return search(query, limit: limit, excludeIds: excludeIds);
  }

  static int _score(CredentialDefinition def, String q) {
    var score = 0;
    final label = def.label.toLowerCase();

    if (label == q) score += 100;
    if (label.contains(q)) score += 20 + q.length;
    if (q.contains(label)) score += 15;

    for (final alias in def.aliases) {
      final a = alias.toLowerCase();
      if (a == q) score += 80;
      if (a.contains(q) || q.contains(a)) score += 12 + a.length;
    }

    // 토큰 단위 (공백·특수문자 분리)
    final tokens = q.split(RegExp(r'[\s·/(),]+')).where((t) => t.length >= 2);
    for (final token in tokens) {
      if (label.contains(token)) score += 8;
      for (final alias in def.aliases) {
        if (alias.toLowerCase().contains(token)) score += 6;
      }
    }

    return score;
  }
}

class _Scored {
  const _Scored(this.def, this.score);
  final CredentialDefinition def;
  final int score;
}
