import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/trust/local_company_rating_repository.dart';
import 'package:map/core/trust/presentation/company_rating_dialog.dart';

/// 정산 완료 후 미평가 건에 대해 구직자 평가 다이얼로그 자동 표시
abstract final class CompanyRatingPromptService {
  static Future<void> promptIfNeeded(
    BuildContext context, {
    required List<HiringApplication> shifts,
    required bool isActive,
  }) async {
    if (!ProductFeatureFlags.isSeekerEmployerRatingEnabled) return;
    if (!isActive || !context.mounted) return;

    final repo = await LocalCompanyRatingRepository.create();
    for (final shift in shifts) {
      if (shift.status != HiringApplicationStatus.commissionPaid) continue;
      final companyKey = shift.companyKey;
      if (companyKey == null || companyKey.isEmpty) continue;
      if (await repo.hasRated(shift.id)) continue;
      if (!context.mounted) return;
      await showCompanyRatingDialog(context, shift);
      return;
    }
  }
}
