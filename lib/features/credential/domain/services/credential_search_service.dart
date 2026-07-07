import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/credential/domain/entities/credential_definition.dart';

/// 자격증 검색·연관검색어
abstract final class CredentialSearchService {
  /// 「보건」검색 시 항상 노출 — 식품 보건증 + 건설 안전보건교육 (혼동 방지)
  static const boGeonPinnedIds = [
    'health_certificate',
    'construction_safety_basic',
  ];

  static List<CredentialDefinition> search(
    String query, {
    int limit = 12,
    Set<String> excludeIds = const {},
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    if (_isBoGeonQuery(q)) {
      return _pinned(
        boGeonPinnedIds,
        excludeIds: excludeIds,
        limit: limit,
      );
    }

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

  static List<CredentialDefinition> pinnedBoGeon({
    Set<String> excludeIds = const {},
  }) =>
      _pinned(boGeonPinnedIds, excludeIds: excludeIds);

  static List<CredentialDefinition> _pinned(
    List<String> ids, {
    required Set<String> excludeIds,
    int limit = 12,
  }) {
    final result = <CredentialDefinition>[];
    for (final id in ids) {
      if (excludeIds.contains(id)) continue;
      final def = CredentialCatalog.findById(id);
      if (def != null) result.add(def);
      if (result.length >= limit) break;
    }
    return result;
  }

  static int _score(CredentialDefinition def, String q) {
    if (_isBoGeonQuery(q) &&
        def.id == CredentialCatalog.constructionSafetyBasic.id) {
      return 0;
    }

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

    final tokens = q.split(RegExp(r'[\s·/(),]+')).where((t) => t.length >= 2);
    for (final token in tokens) {
      if (label.contains(token)) score += 8;
      for (final alias in def.aliases) {
        if (alias.toLowerCase().contains(token)) score += 6;
      }
    }

    return score;
  }

  static bool _isBoGeonQuery(String q) {
    if (q == '보건' || q == '보건증') return true;
    return q.startsWith('건강진단') ||
        q.startsWith('건강증명') ||
        q.contains('보건증');
  }
}

class _Scored {
  const _Scored(this.def, this.score);
  final CredentialDefinition def;
  final int score;
}
