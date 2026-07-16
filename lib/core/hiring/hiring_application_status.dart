import 'package:map/core/config/product_feature_flags.dart';

/// 채용 워크플로우 상태 — PUSH 수신 후 지원부터 수수료 결제까지
enum HiringApplicationStatus {
  /// 지원 전 공고 문의 채팅
  inquiry,
  applied,
  chatting,
  scheduled,
  checkedIn,
  commissionPaid,
  rejected,
  noShow,
}

extension HiringApplicationStatusX on HiringApplicationStatus {
  String get label => switch (this) {
        HiringApplicationStatus.inquiry => '문의 중',
        HiringApplicationStatus.applied => '접수 완료',
        HiringApplicationStatus.chatting => '채팅 중',
        HiringApplicationStatus.scheduled => '출근 예정',
        HiringApplicationStatus.checkedIn => '상호 확인 완료',
        HiringApplicationStatus.commissionPaid =>
          ProductFeatureFlags.isHiringCommissionEnabled ? '정산 완료' : '채용 완료',
        HiringApplicationStatus.rejected => '불합격',
        HiringApplicationStatus.noShow => '노쇼',
      };

  /// 지원하기 버튼·중복 지원 검사에 사용 (문의만 한 건은 제외)
  bool get countsAsApplied => switch (this) {
        HiringApplicationStatus.inquiry ||
        HiringApplicationStatus.rejected ||
        HiringApplicationStatus.noShow =>
          false,
        _ => true,
      };

  bool get isActive => switch (this) {
        HiringApplicationStatus.rejected => false,
        HiringApplicationStatus.noShow => false,
        _ => true,
      };

  /// 서버 전송용 — 서버는 스네이크케이스를 기대함(예: 셔틀 노선 열람 자격 판정).
  String get wireValue => switch (this) {
        HiringApplicationStatus.checkedIn => 'checked_in',
        HiringApplicationStatus.commissionPaid => 'commission_paid',
        HiringApplicationStatus.noShow => 'no_show',
        _ => name,
      };
}

/// 서버에서 내려온 스네이크케이스 상태값을 역파싱 — [HiringApplicationStatusX.wireValue]의 역함수.
HiringApplicationStatus? hiringApplicationStatusFromWire(String? value) {
  if (value == null) return null;
  for (final status in HiringApplicationStatus.values) {
    if (status.wireValue == value) return status;
  }
  return null;
}
