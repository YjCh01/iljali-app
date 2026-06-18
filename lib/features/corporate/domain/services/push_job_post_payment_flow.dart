import 'package:flutter/material.dart';

import 'package:map/core/constants/app_routes.dart';

import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';



class PushJobPostPaymentResult {

  const PushJobPostPaymentResult({

    required this.notificationSettings,

    this.paymentRecord,

    this.extraPushFeeKrw = 0,

    this.dispatchRadiusTier,
    this.recruitmentPushCount = 0,
  });



  final JobPostNotificationSettings? notificationSettings;

  final JobPostPaymentRecord? paymentRecord;

  final int extraPushFeeKrw;

  final PushRadiusTier? dispatchRadiusTier;
  final int recruitmentPushCount;

}



/// 거점·핀 설정(활성화)과 PUSH 발송(모집하기)은 별도 플로우.
///
/// 공고 등록·거점 설정은 무료/크레딧 활성화만 처리하며, PUSH는
/// [PushDispatchService.prepareQuickRecruitPush] — 공고 탭 「모집하기」에서만 실행.

class PushJobPostPaymentFlow {
  const PushJobPostPaymentFlow();

  Future<PushJobPostPaymentResult?> collect({

    required BuildContext context,

    JobPostNotificationSettings? notificationSettings,

    CorporateMemberProfile? profile,

    String? companyKey,

  }) async {

    var settings = notificationSettings;

    JobPostPaymentRecord? paymentRecord;

    const extraPushFeeKrw = 0;

    if (settings?.requiresPayment == true) {

      final bundle = settings!.paymentBundle;

      if (!context.mounted) return null;

      final paymentResult =

          await Navigator.of(context).pushNamed<PaymentCompletionResult>(

        AppRoutes.corporateNotificationPayment,

        arguments: bundle,

      );

      if (!context.mounted) return null;

      if (paymentResult == null) return null;

      paymentRecord = paymentResult.record;

      settings = settings.copyWith(

        paymentCompleted: true,

        spotPaymentCompleted: true,

        basePoints: settings.basePoints

            .map((point) => point.copyWith(isPaid: true))

            .toList(),

      );

    }



    return PushJobPostPaymentResult(

      notificationSettings: settings,

      paymentRecord: paymentRecord,

      extraPushFeeKrw: extraPushFeeKrw,

    );

  }

}


