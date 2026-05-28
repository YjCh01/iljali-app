/// 공고 데이터 변경 시 구직자 지도·목록 갱신용 (동일 앱 세션)
abstract final class JobBoardRefresh {
  static bool _dirty = false;

  static void markUpdated() => _dirty = true;

  static bool consumeIfDirty() {
    if (!_dirty) return false;
    _dirty = false;
    return true;
  }
}
