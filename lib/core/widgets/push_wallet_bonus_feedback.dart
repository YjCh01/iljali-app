import 'package:flutter/material.dart';
import 'package:map/core/widgets/transient_snack_bar.dart';
import 'package:map/features/corporate/domain/entities/push_package_catalog.dart';
import 'package:map/features/corporate/domain/entities/push_wallet_load_outcome.dart';

void showPushWalletBonusSnackBar(
  BuildContext context,
  PushWalletLoadOutcome outcome,
) {
  if (!outcome.grantedAnyBonus) return;
  final parts = <String>[];
  if (outcome.grantedSignupBonus) {
    parts.add('가입 보너스 ${PushPackageCatalog.signupBonusPushes}회');
  }
  if (outcome.grantedVerificationBonus) {
    parts.add('사업자 인증 보너스 ${PushPackageCatalog.verificationBonusPushes}회');
  }
  showTransientSnackBar(
    context,
    '${parts.join(' · ')} 일자리 알림핀이 충전되었습니다.',
  );
}
