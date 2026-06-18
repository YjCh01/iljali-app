import 'package:flutter/material.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_delegate_info.dart';
import 'package:map/features/corporate/domain/entities/corporate_payment_preference.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_request_kind.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_line_item.dart';
import 'package:map/features/corporate/domain/entities/pay_or_request_result.dart';
import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';
import 'package:map/features/corporate/domain/services/corporate_payment_access_service.dart';
import 'package:map/features/corporate/domain/services/job_post_payment_request_service.dart';
import 'package:map/features/corporate/presentation/pages/corporate_notification_payment_args.dart';

/// 유료 결제 — 기본은 직접 결제, 위임 시에만 요청 버튼으로 담당자에게 전달
class CorporatePaymentNavigationHelper {
  CorporatePaymentNavigationHelper({
    CorporatePaymentAccessService? accessService,
    JobPostPaymentRequestService? requestService,
  })  : _accessService = accessService,
        _requestService = requestService;

  CorporatePaymentAccessService? _accessService;
  JobPostPaymentRequestService? _requestService;

  Future<CorporatePaymentAccessService> _access() async =>
      _accessService ??= CorporatePaymentAccessService();

  Future<JobPostPaymentRequestService> _requests() async =>
      _requestService ??= JobPostPaymentRequestService();

  Future<PayOrRequestResult> payOrRequest({
    required BuildContext context,
    required PushPaymentBundle bundle,
    required JobPostPaymentRequestKind kind,
    String? jobPostId,
    String? jobTitle,
    String? productLabel,
    bool showSnackBar = true,
    CorporatePaymentPreference preference = CorporatePaymentPreference.auto,
  }) async {
    if (!bundle.requiresPayment) {
      return const PayOrRequestResult(outcome: PayOrRequestOutcome.notRequired);
    }

    final user = AuthSession.instance.currentUser;
    final profile = user?.corporateProfile;
    final email = user?.email ?? '';
    final companyKey = profile?.companyKey ?? '';
    if (companyKey.isEmpty || email.isEmpty) {
      if (showSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('기업 프로필이 필요합니다.')),
        );
      }
      return const PayOrRequestResult(
        outcome: PayOrRequestOutcome.blocked,
        message: '기업 프로필이 필요합니다.',
      );
    }

    // 직접 결제(auto·direct)는 위임 여부와 무관하게 항상 결제 화면으로
    if (preference != CorporatePaymentPreference.request) {
      return _payDirect(
        context: context,
        bundle: bundle,
        paymentKind: kind,
      );
    }

    final delegate = await (await _access()).loadDelegateInfo(
      companyKey: companyKey,
      email: email,
    );
    if (!context.mounted) {
      return const PayOrRequestResult(outcome: PayOrRequestOutcome.blocked);
    }

    if (!delegate.canRequestPayment) {
      if (showSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '결제 위임이 설정되지 않았습니다. '
              '위임 후 담당자에게 결제를 요청할 수 있습니다.',
            ),
          ),
        );
      }
      return const PayOrRequestResult(
        outcome: PayOrRequestOutcome.blocked,
        message: '결제 위임이 없습니다.',
      );
    }

    return _sendPaymentRequest(
      context: context,
      delegate: delegate,
      companyKey: companyKey,
      email: email,
      userName: user?.name,
      bundle: bundle,
      kind: kind,
      jobPostId: jobPostId,
      jobTitle: jobTitle ?? profile?.companyName ?? '채용 공고',
      productLabel: productLabel,
      showSnackBar: showSnackBar,
    );
  }

  Future<PayOrRequestResult> _payDirect({
    required BuildContext context,
    required PushPaymentBundle bundle,
    JobPostPaymentRequestKind? paymentKind,
  }) async {
    final payment = await Navigator.of(context).pushNamed<PaymentCompletionResult>(
      AppRoutes.corporateNotificationPayment,
      arguments: CorporateNotificationPaymentArgs(
        bundle: bundle,
        paymentKind: paymentKind ?? bundle.paymentKind,
      ),
    );
    if (payment != null) {
      return PayOrRequestResult(
        outcome: PayOrRequestOutcome.paid,
        payment: payment,
      );
    }
    return const PayOrRequestResult(outcome: PayOrRequestOutcome.cancelled);
  }

  Future<PayOrRequestResult> _sendPaymentRequest({
    required BuildContext context,
    required CorporatePaymentDelegateInfo delegate,
    required String companyKey,
    required String email,
    required PushPaymentBundle bundle,
    required JobPostPaymentRequestKind kind,
    String? jobPostId,
    required String jobTitle,
    String? productLabel,
    String? userName,
    bool showSnackBar = true,
  }) async {
    try {
      final request = await (await _requests()).createRequest(
        companyKey: companyKey,
        requesterEmail: email,
        requesterDisplayName: userName,
        bundle: bundle,
        kind: kind,
        jobTitle: jobTitle,
        jobPostId: jobPostId,
        productLabel: productLabel,
        payerEmail: delegate.payerEmail,
      );
      if (showSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${delegate.payerShortLabel}님에게 '
              '「${request.productLabel}」 결제 요청을 보냈습니다.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return PayOrRequestResult(
        outcome: PayOrRequestOutcome.requestSent,
        request: request,
        message: '${delegate.payerShortLabel}님에게 결제 요청을 보냈습니다.',
      );
    } on StateError catch (e) {
      final message = switch (e.message) {
        'payer_not_found' => '결제 권한자가 없습니다. 대표·관리자에게 권한을 요청해 주세요.',
        'no_payment_required' => '결제할 항목이 없습니다.',
        _ => '결제 요청에 실패했습니다.',
      };
      if (showSnackBar && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
      return PayOrRequestResult(
        outcome: PayOrRequestOutcome.blocked,
        message: message,
      );
    }
  }

  Future<List<JobPostPaymentRequest>> sendBatchRequests({
    required BuildContext context,
    required List<JobPostPaymentLineItem> items,
    required String jobTitle,
    String? jobPostId,
  }) async {
    final user = AuthSession.instance.currentUser;
    final profile = user?.corporateProfile;
    final email = user?.email ?? '';
    final companyKey = profile?.companyKey ?? '';
    if (companyKey.isEmpty || email.isEmpty || items.isEmpty) return [];

    final delegate = await (await _access()).loadDelegateInfo(
      companyKey: companyKey,
      email: email,
    );
    if (!delegate.canRequestPayment) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('결제 권한자가 없습니다.')),
        );
      }
      return [];
    }

    final service = await _requests();
    final created = <JobPostPaymentRequest>[];
    for (final item in items) {
      final request = await service.createRequest(
        companyKey: companyKey,
        requesterEmail: email,
        requesterDisplayName: user?.name,
        bundle: item.bundle,
        kind: item.kind,
        jobTitle: jobTitle,
        jobPostId: jobPostId,
        productLabel: item.label,
        payerEmail: delegate.payerEmail,
      );
      created.add(request);
    }

    if (context.mounted && created.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            created.length == 1
                ? '${delegate.payerShortLabel}님에게 결제 요청을 보냈습니다.'
                : '${delegate.payerShortLabel}님에게 결제 요청 ${created.length}건을 보냈습니다.',
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: '내 요청',
            onPressed: () {},
          ),
        ),
      );
    }
    return created;
  }
}
