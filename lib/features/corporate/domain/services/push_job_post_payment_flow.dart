import 'package:flutter/material.dart';

import 'package:map/core/constants/app_routes.dart';

import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';

import 'package:map/features/corporate/domain/entities/push_notification_settings.dart';

import 'package:map/features/corporate/domain/services/push_dispatch_service.dart';



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



/// 공고 등록 무료 · 모집하기 시 지역 푸시권/일일 무료 소진

class PushJobPostPaymentFlow {
  PushJobPostPaymentFlow({PushDispatchService? dispatchService})
      : _dispatchService = dispatchService ?? PushDispatchService();



  final PushDispatchService _dispatchService;



  Future<PushJobPostPaymentResult?> collect({

    required BuildContext context,

    JobPostNotificationSettings? notificationSettings,

    CorporateMemberProfile? profile,

    String? companyKey,

  }) async {

    var settings = notificationSettings;

    JobPostPaymentRecord? paymentRecord;

    var extraPushFeeKrw = 0;

    PushRadiusTier? dispatchRadiusTier;
    var recruitmentPushCount = 0;



    final activeProfile = profile;

    if (settings?.hasConfiguredBase == true && activeProfile != null) {

      final prepared = await _dispatchService.prepareRegistrationPush(
        context: context,
        profile: activeProfile,
        settings: settings!,
      );

      if (!context.mounted) return null;

      if (prepared == null) return null;

      dispatchRadiusTier = prepared.radiusTier;
      extraPushFeeKrw = prepared.paymentKrw;
      paymentRecord = prepared.paymentRecord;
      recruitmentPushCount = prepared.recruitmentPushCount;

    }



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

      dispatchRadiusTier: dispatchRadiusTier,
      recruitmentPushCount: recruitmentPushCount,

    );

  }

}


