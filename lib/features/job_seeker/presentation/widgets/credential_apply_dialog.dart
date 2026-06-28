import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/credential/domain/entities/credential_catalog.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_credentials.dart';

/// 공고 필수 자격 — 보유 확인 후 지원 진행
Future<bool> showRequiredCredentialsApplyDialog(
  BuildContext context, {
  required List<String> credentialIds,
}) async {
  if (credentialIds.isEmpty) return true;

  final profile = AuthSession.instance.currentUser?.seekerProfile;
  final missingIds = credentialIds
      .where((id) => !(profile?.holdingFor(id)?.isComplete ?? false))
      .toList();

  final labels = CredentialCatalog.labelsForIds(credentialIds);
  final heldLabels = credentialIds
      .where((id) => profile?.holdingFor(id)?.isComplete ?? false)
      .map((id) => CredentialCatalog.findById(id)?.label ?? id)
      .toList();
  final missingLabels = CredentialCatalog.labelsForIds(missingIds);

  if (missingIds.isNotEmpty) {
    final goRegister = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('필수 자격·면허 미등록'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '아래 자격증을 내 프로필에 등록(사진 업로드)한 뒤 지원할 수 있습니다.',
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
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('닫기'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('자격증 등록'),
          ),
        ],
      ),
    );
    if (goRegister == true && context.mounted) {
      await Navigator.of(context).pushNamed(AppRoutes.seekerMyCredentials);
    }
    return false;
  }

  final body = labels.map((label) {
    final held = heldLabels.contains(label);
    return held ? '• $label (보유)' : '• $label';
  }).join('\n');

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('필수 자격·면허 안내'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '해당 공고는 아래 자격증 보유가 필요합니다.\n'
            '채용 확정 전까지는 기업에 자격증 이름만 공개되며, '
            '원본은 채용 확정 후 열람·다운로드됩니다.\n\n지원하시겠습니까?',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('아니오 (지원취소)'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('예'),
        ),
      ],
    ),
  );

  return confirmed == true;
}
