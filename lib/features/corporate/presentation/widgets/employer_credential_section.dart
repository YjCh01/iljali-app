import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/domain/entities/employer_visible_credential.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_credential_viewer_page.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_document_image.dart';

/// 기업회원 — 지원자 자격증 섹션 (채용 확정 전: 이름·보유만 / 확정 후: 열람·다운로드)
class EmployerCredentialSection extends StatelessWidget {
  const EmployerCredentialSection({
    super.key,
    required this.credentials,
    required this.canViewDocuments,
    this.requiredOnly = false,
  });

  final List<EmployerVisibleCredential> credentials;
  final bool canViewDocuments;
  final bool requiredOnly;

  @override
  Widget build(BuildContext context) {
    if (credentials.isEmpty) return const SizedBox.shrink();

    final title = requiredOnly ? '필수 자격·면허' : '자격·면허·이수증';

    return CorporateSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!canViewDocuments) ...[
            const SizedBox(height: 8),
            Text(
              '채용 확정 전에는 보유 여부와 자격증 이름만 확인할 수 있습니다. '
              '원본 열람·다운로드는 채용 확정 후 가능합니다.',
              style: TextStyle(
                fontSize: 12,
                height: 1.45,
                color: AppColors.textSecondary.withValues(alpha: 0.92),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ...credentials.map(
            (credential) => _CredentialRow(
              credential: credential,
              canViewDocuments: canViewDocuments,
            ),
          ),
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.credential,
    required this.canViewDocuments,
  });

  final EmployerVisibleCredential credential;
  final bool canViewDocuments;

  @override
  Widget build(BuildContext context) {
    final held = credential.isHeld;
    final canOpen = canViewDocuments && credential.canViewDocument;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                held ? Icons.verified_outlined : Icons.help_outline_rounded,
                size: 18,
                color: held ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  credential.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: held
                      ? AppColors.primaryLight.withValues(alpha: 0.25)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  held ? '보유' : '미등록',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: held ? AppColors.primary : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          if (canOpen) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: () => openSeekerCredentialViewer(
                  context,
                  label: credential.label,
                  imagePath: credential.imagePath!,
                ),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: seekerDocumentImage(credential.imagePath!, height: 120),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => openSeekerCredentialViewer(
                context,
                label: credential.label,
                imagePath: credential.imagePath!,
              ),
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('원본 열람·다운로드'),
            ),
          ],
        ],
      ),
    );
  }
}
