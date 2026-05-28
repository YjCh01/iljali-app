/// 지원·근태·예정자 탭 갱신 신호
class HiringRefresh {
  HiringRefresh._();

  static bool _dirty = false;

  static void markUpdated() => _dirty = true;

  static bool consumeIfDirty() {
    if (!_dirty) return false;
    _dirty = false;
    return true;
  }
}
