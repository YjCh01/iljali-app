/// 셔틀 운행 안내 — 구직자 노출 고정 문구
abstract final class ShuttleOperationGuideCopy {
  static const driverDisclaimer =
      '버스 운행기사는 당사 직원이 아닙니다. 상호 예의와 매너를 갖춰주세요. '
      '기사님 전화번호는 개인정보 보호를 위하여 공개되지 않습니다. '
      '문의사항은 현장 직원 혹은 채팅으로 전달바랍니다.';

  static const boardingWaitRecommendation =
      '탑승을 위해서 5분 전 대기를 권장합니다.';

  static final _legacyArrivalByTimePattern = RegExp(
    r'셔틀은\s*\d{1,2}:\d{2}\s*까지\s*도착을\s*권장합니다\.',
  );

  /// 구버전·시간 하드코딩 문구를 표준 안내로 치환
  static String normalizeGuideText(String raw) {
    return raw.trim().replaceAll(
          _legacyArrivalByTimePattern,
          boardingWaitRecommendation,
        );
  }

  static String boardingNotesForDisplay(String custom) {
    final normalized = normalizeGuideText(custom);
    if (normalized.isEmpty) return boardingWaitRecommendation;
    if (normalized.contains(boardingWaitRecommendation)) return normalized;
    return '$normalized $boardingWaitRecommendation';
  }

  static String arrivalInstructionsForDisplay(String custom) =>
      normalizeGuideText(custom);
}
