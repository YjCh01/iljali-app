import 'package:flutter/material.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/presentation/widgets/job_post_import_labels.dart';

/// 홈·공고 등록 진입 — 직접 작성 vs AI 가져오기
enum CorporateCreateJobPostEntry { write, import }

Future<CorporateCreateJobPostEntry?> showCorporateCreateJobPostEntrySheet(
  BuildContext context,
) {
  return showAdaptiveSheet<CorporateCreateJobPostEntry>(
    context: context,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: CorporateCreateJobPostEntryPanel(
        onWrite: () => Navigator.of(context).pop(
          CorporateCreateJobPostEntry.write,
        ),
        onImport: () => Navigator.of(context).pop(
          CorporateCreateJobPostEntry.import,
        ),
      ),
    ),
  );
}

/// 홈·공고 탭 등에서 바텀시트와 동일한 공고 등록 진입 UI
class CorporateCreateJobPostEntryPanel extends StatelessWidget {
  const CorporateCreateJobPostEntryPanel({
    super.key,
    required this.onWrite,
    required this.onImport,
    this.showHeader = true,
  });

  final VoidCallback onWrite;
  final VoidCallback onImport;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          const Text(
            '공고 등록',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '공고 등록은 무료입니다.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 14),
        ],
        CorporateCreateJobPostEntryTile(
          title: '일자리 직접 작성',
          subtitle: '근무지·급여·일정을 직접 입력합니다.',
          icon: Icons.edit_outlined,
          onTap: onWrite,
        ),
        const SizedBox(height: 8),
        CorporateCreateJobPostEntryTile(
          title: 'AI로 공고 가져오기',
          subtitle: JobPostImportCopy.ctaLabel,
          leading: const AiSparkleMark(size: 20, badge: true),
          onTap: onImport,
        ),
      ],
    );
  }
}

class CorporateCreateJobPostEntryTile extends StatelessWidget {
  const CorporateCreateJobPostEntryTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.icon,
    this.leading,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.searchBarBorder),
          ),
          child: Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 12),
              ] else if (icon != null) ...[
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textSecondary.withValues(alpha: 0.95),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
