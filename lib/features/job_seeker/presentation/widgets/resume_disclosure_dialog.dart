import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_member_profile.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';
import 'package:map/features/job_seeker/domain/utils/seeker_profile_credentials.dart';

/// 공고 필수 이력서 항목 공개 동의
Future<Set<ResumeItemKind>?> showResumeDisclosureFlow(
  BuildContext context, {
  required List<ResumeItemKind> requiredItems,
  required SeekerResumeContent resume,
  SeekerMemberProfile? profile,
}) async {
  if (requiredItems.isEmpty) return {};

  final missing = requiredItems.where((kind) {
    if (profile != null) return !profile.hasResumeContentFor(kind);
    return !resume.hasContentFor(kind);
  }).toList();

  if (missing.isNotEmpty) {
    final labels = missing.map((k) => k.label).join(', ');
    final needsCredentials = missing.any(
      (k) =>
          k == ResumeItemKind.license || k == ResumeItemKind.certification,
    );
    final goEdit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이력서 작성 필요'),
        content: Text(
          '필수 확인 항목에 $labels이(가) 포함되어 있으나 '
          '작성된 내용이 없습니다.\n'
          '${needsCredentials ? '자격·면허는 사진 등록까지 완료해야 합니다.\n' : ''}'
          '이력서를 작성하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('이력서 작성'),
          ),
        ],
      ),
    );
    if (goEdit == true && context.mounted) {
      final route = needsCredentials && missing.every(
            (k) =>
                k == ResumeItemKind.license ||
                k == ResumeItemKind.certification,
          )
          ? AppRoutes.seekerMyCredentials
          : AppRoutes.seekerResumeEdit;
      await Navigator.of(context).pushNamed(route);
    }
    return null;
  }

  final labels = requiredItems.map((k) => '• ${k.label}').join('\n');
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('이력서 공개 동의'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '이 공고는 아래 항목의 이력서 확인을 요청합니다.',
            style: TextStyle(height: 1.45),
          ),
          const SizedBox(height: 12),
          Text(
            labels,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '해당 항목을 기업에 공개하시겠습니까?',
            style: TextStyle(
              color: AppColors.textSecondary.withValues(alpha: 0.95),
              height: 1.45,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          child: const Text('공개하고 지원'),
        ),
      ],
    ),
  );

  if (confirmed != true) return null;
  return requiredItems.toSet();
}
