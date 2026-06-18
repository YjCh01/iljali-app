import 'package:flutter/material.dart';
import 'package:map/features/corporate/domain/entities/employer_push_wallet.dart';
import 'package:map/features/corporate/domain/entities/exposure_activation_credit_mode.dart';

/// 알림핀·정류장 활성화 — 노출 이용권만 사용 (통합핀 제거)
Future<ExposureActivationCreditMode?> showExposureActivationModeSheet(
  BuildContext context, {
  required EmployerPushWallet wallet,
  String title = '이용권 선택',
  String? subtitle,
}) {
  if (wallet.packageCredits <= 0) {
    return Future.value(null);
  }

  return Future.value(ExposureActivationCreditMode.exposureOnly);
}
