import 'package:map/core/config/product_feature_flags.dart';

/// 채용 워크플로우 상태 — PUSH 수신 후 지원부터 수수료 결제까지
enum HiringApplicationStatus {
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
        HiringApplicationStatus.applied => '접수 완료',
        HiringApplicationStatus.chatting => '채팅 중',
        HiringApplicationStatus.scheduled => '출근 예정',
        HiringApplicationStatus.checkedIn => '상호 확인 완료',
        HiringApplicationStatus.commissionPaid =>
          ProductFeatureFlags.isHiringCommissionEnabled ? '정산 완료' : '채용 완료',
        HiringApplicationStatus.rejected => '불합격',
        HiringApplicationStatus.noShow => '노쇼',
      };

  bool get isActive => switch (this) {
        HiringApplicationStatus.rejected => false,
        HiringApplicationStatus.noShow => false,
        _ => true,
      };
}
