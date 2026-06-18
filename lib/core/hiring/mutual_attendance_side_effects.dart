import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/hiring/commission_calculator.dart';
import 'package:map/core/hiring/application_chat_message_repository.dart';
import 'package:map/core/hiring/commission_chat_prompt_service.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/notifications/kakao_alimtalk_notification_service.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/data/repositories/corporate_organization_repository.dart';
import 'package:map/features/corporate/domain/services/commission_payer_resolver.dart';

/// 상호 출근 확인 직후 — 채팅·알림톡·결제 프롬프트 (결제 권한자 라우팅)
abstract final class MutualAttendanceSideEffects {
  static Future<void> handle(HiringApplication application) async {
    if (!ProductFeatureFlags.isHiringCommissionEnabled) return;
    if (!application.isMutuallyConfirmed || !application.needsCommissionPayment) {
      return;
    }

    final resolver = await CommissionPayerResolver.create();
    final payerEmail = await resolver.resolvePayerEmail(
      companyKey: application.companyKey,
      recruiterEmail: application.recruiterEmail,
    );

    final chatRepo = await ApplicationChatMessageRepository.create();
    await chatRepo.appendSystemMessage(
      applicationId: application.id,
      text:
          '출근 확인이 완료되었습니다.\n'
          '기업 담당자께서는 수수료 ${CommissionCalculator.formatKrw(CommissionCalculator.forApplication(application))} 결제를 진행해 주세요.',
    );

    final prompt = await CommissionChatPromptService.create();
    await prompt.markPending(application.id, payerEmail: payerEmail);

    final orgRepo = await CorporateOrganizationRepository.create();
    final payerMember = payerEmail.isNotEmpty && application.companyKey != null
        ? await orgRepo.findMember(
            companyKey: application.companyKey!,
            email: payerEmail,
          )
        : null;

    final user = AuthSession.instance.currentUser;
    final fallbackPhone =
        user?.isCorporate == true ? user?.phone : null;
    final payerPhone = payerMember?.phone ?? fallbackPhone ?? '01000000000';
    final payerName = payerMember?.name ?? application.companyName;

    final kakao = await KakaoAlimtalkNotificationService.create();
    await kakao.notifyEmployerCommissionDue(
      application: application,
      employerPhone: payerPhone,
      employerName: payerName,
    );
  }
}
