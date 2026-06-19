import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/services/push_wallet_service.dart';

/// B(결제 권한자) 결제 완료 후 회사 지갑에 이용권 충전
class JobPostPaymentFulfillmentService {
  JobPostPaymentFulfillmentService({PushWalletService? walletService})
      : _walletService = walletService ?? PushWalletService();

  final PushWalletService _walletService;

  Future<String> fulfillAfterPayment(JobPostPaymentRequest request) async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) {
      return '결제가 완료되었습니다.';
    }

    switch (request.kind) {
      case JobPostPaymentRequestKind.pushTicket:
        await _walletService.addPushTicketPurchase(
          profile,
          count: request.bundle.spotCount,
        );
        return 'PUSH 이용권 ${request.bundle.spotCount}회가 충전되었습니다.';
      case JobPostPaymentRequestKind.jobPinExposure:
      case JobPostPaymentRequestKind.shuttleStopExposure:
      case JobPostPaymentRequestKind.packagePurchase:
      case JobPostPaymentRequestKind.extraPush:
        await _walletService.addExposureCredits(
          profile,
          count: request.bundle.spotCount,
        );
        return '일자리 알림핀 ${request.bundle.spotCount}회가 충전되었습니다. '
            '채용 담당자가 노출을 활성화할 수 있습니다.';
    }
  }
}
