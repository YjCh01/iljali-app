import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';

/// 기업회원 — 지원자 자격증 원본 열람·다운로드 권한
abstract final class HiringCredentialAccess {
  /// 채용 확정(상호 출근 확인 완료 또는 채용 완료) 이후에만 원본 열람 가능
  static bool canEmployerViewCredentialDocuments(HiringApplication application) {
    if (application.status == HiringApplicationStatus.commissionPaid) {
      return true;
    }
    return application.isMutuallyConfirmed;
  }
}
