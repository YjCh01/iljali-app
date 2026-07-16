import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_credentials.dart';

/// [showRequiredCredentialsApplyDialog] 결과 — 자격증 보유 여부와 무관하게 지원은
/// 항상 진행 가능. 미보유 자격증이 있으면 등록 유도만 하고, 실제 검증은 채용 확정 후 진행.
class RequiredCredentialDialogResult {
  const RequiredCredentialDialogResult({
    required this.proceed,
    required this.missingCredentialIds,
  });

  final bool proceed;
  final List<String> missingCredentialIds;
}

/// 공고 필수 자격 안내 — 지원은 자격증 등록 여부와 관계없이 항상 가능하며,
/// 미보유 시 등록을 유도만 한다(지원을 막지 않음).
Future<RequiredCredentialDialogResult> showRequiredCredentialsApplyDialog(
  BuildContext context, {
  required List<String> credentialIds,
}) async {
  if (credentialIds.isEmpty) {
    return const RequiredCredentialDialogResult(
      proceed: true,
      missingCredentialIds: [],
    );
  }

  final profile = AuthSession.instance.currentUser?.seekerProfile;
  final missingIds = credentialIds
      .where((id) => !(profile?.holdingFor(id)?.isComplete ?? false))
      .toList();

  if (missingIds.isEmpty) {
    return RequiredCredentialDialogResult(
      proceed: true,
      missingCredentialIds: missingIds,
    );
  }

  final missingLabels = CredentialCatalog.labelsForIds(missingIds);
  final decision = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('필수 자격·면허 안내'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이 공고는 아래 자격증 보유를 확인합니다.\n'
            '자격증 등록 여부와 관계없이 지금 지원할 수 있습니다.\n'
            '아직 등록하지 않았다면, 지원을 마친 직후 이력서에서 '
            '자격증을 등록해 주세요.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          ...missingLabels.map(
            (label) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• $label', style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop('cancel'),
          child: const Text('취소'),
        ),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop('register'),
          child: const Text('지금 등록하기'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop('proceed'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('지원 계속하기'),
        ),
      ],
    ),
  );

  if (decision == 'register') {
    if (context.mounted) {
      await Navigator.of(context).pushNamed(AppRoutes.seekerMyCredentials);
    }
    return RequiredCredentialDialogResult(
      proceed: false,
      missingCredentialIds: missingIds,
    );
  }

  return RequiredCredentialDialogResult(
    proceed: decision == 'proceed',
    missingCredentialIds: missingIds,
  );
}
