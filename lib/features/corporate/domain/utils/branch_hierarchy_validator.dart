import 'package:map/features/corporate/domain/entities/corporate_branch.dart';

/// Multi-지점 계층 유효성 — 본사 · 지역 · 매장
abstract final class BranchHierarchyValidator {
  static String? validateCreate({
    required BranchLevel level,
    required String? parentBranchId,
    required List<CorporateBranch> existing,
  }) {
    if (level == BranchLevel.hq && parentBranchId != null) {
      return '본사는 상위 지점을 지정할 수 없습니다.';
    }
    if (level == BranchLevel.regional) {
      if (parentBranchId == null) {
        return '지역 지점은 본사 하위로 등록해 주세요.';
      }
      final parent = _find(existing, parentBranchId);
      if (parent == null) return '상위 지점을 찾을 수 없습니다.';
      if (parent.level != BranchLevel.hq) {
        return '지역 지점의 상위는 본사만 가능합니다.';
      }
    }
    if (level == BranchLevel.store) {
      if (parentBranchId == null) {
        return '매장은 본사 또는 지역 하위로 등록해 주세요.';
      }
      final parent = _find(existing, parentBranchId);
      if (parent == null) return '상위 지점을 찾을 수 없습니다.';
      if (parent.level == BranchLevel.store) {
        return '매장의 상위는 본사·지역만 가능합니다.';
      }
    }
    return null;
  }

  static CorporateBranch? _find(List<CorporateBranch> list, String id) {
    for (final b in list) {
      if (b.id == id) return b;
    }
    return null;
  }
}
