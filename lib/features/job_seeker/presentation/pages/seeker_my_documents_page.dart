import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/legal/legal_consent_catalog.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/adaptive_sheet.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/job_seeker/data/repositories/seeker_document_repository.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_document_storage.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_document_image.dart';

/// 신분증 등록 안내 — 급여·세금 신고 목적
const _idCardRegistrationNotice =
    '신분증은 급여·원천징수 세금 신고에 사용됩니다. '
    '주민등록번호를 가리거나 식별이 어렵게 올리면, '
    '근무 회사 담당자가 다시 제출을 요청할 수 있습니다.';

/// 구직자 — 신분증·통장사본 등록 (내정보)
class SeekerMyDocumentsPage extends StatefulWidget {
  const SeekerMyDocumentsPage({super.key});

  @override
  State<SeekerMyDocumentsPage> createState() => _SeekerMyDocumentsPageState();
}

class _SeekerMyDocumentsPageState extends State<SeekerMyDocumentsPage> {
  SeekerDocuments _docs = const SeekerDocuments();
  bool _loading = true;
  bool _saving = false;

  bool get _documentConsentAccepted => _docs.isDocumentConsentCurrent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) {
      setState(() => _loading = false);
      return;
    }
    final repo = await SeekerDocumentRepository.create();
    final docs = await repo.load(email);
    if (!mounted) return;
    setState(() {
      _docs = docs;
      _loading = false;
    });
  }

  Future<void> _setDocumentConsent(bool accepted) async {
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) return;

    final updated = accepted
        ? _docs.copyWith(
            documentConsentVersionAccepted:
                LegalConsentCatalog.seekerDocumentConsentVersion,
            documentConsentAcceptedAt: DateTime.now(),
          )
        : _docs.copyWith(
            documentConsentVersionAccepted: null,
            documentConsentAcceptedAt: null,
          );

    final repo = await SeekerDocumentRepository.create();
    await repo.save(email, updated);
    if (!mounted) return;
    setState(() => _docs = updated);
  }

  Future<void> _pickAndSave({
    required bool isIdCard,
    required ImageSource source,
  }) async {
    if (!_documentConsentAccepted) {
      _showConsentRequiredSnackBar();
      return;
    }

    final email = AuthSession.instance.currentUser?.email;
    if (email == null) return;

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1600,
    );
    if (file == null || !mounted) return;

    setState(() => _saving = true);
    final kind = isIdCard ? 'id_card' : 'bank_account';
    final storedPath = await persistSeekerDocumentImage(file, kind);
    if (storedPath == null || !mounted) {
      setState(() => _saving = false);
      return;
    }

    final updated = _docs.copyWith(
      idCardImagePath: isIdCard ? storedPath : _docs.idCardImagePath,
      bankAccountImagePath:
          isIdCard ? _docs.bankAccountImagePath : storedPath,
      updatedAt: DateTime.now(),
    );
    final repo = await SeekerDocumentRepository.create();
    await repo.save(email, updated);
    if (!mounted) return;
    setState(() {
      _docs = updated;
      _saving = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isIdCard ? '신분증이 등록되었습니다.' : '통장사본이 등록되었습니다.',
        ),
      ),
    );
  }

  void _showConsentRequiredSnackBar() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('서류 등록·전송 전에 아래 수집·이용 동의가 필요합니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  Future<void> _showPickSource(bool isIdCard) async {
    if (!_documentConsentAccepted) {
      _showConsentRequiredSnackBar();
      return;
    }

    final source = await showAdaptiveSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('카메라로 촬영'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('앨범에서 선택'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _pickAndSave(isIdCard: isIdCard, source: source);
  }

  void _openDocumentConsentFullText() {
    Navigator.of(context).pushNamed(
      AppRoutes.legalDocuments,
      arguments: {'initialDocumentId': 'seeker_document_consent'},
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: const AppBackButton(),
        automaticallyImplyLeading: false,
        title: const Text('신분증·통장·자격증'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                Text(
                  '채팅에서 바로 보낼 수 있도록 미리 등록해 두세요.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 16),
                _DocumentConsentCard(
                  accepted: _documentConsentAccepted,
                  onChanged: _setDocumentConsent,
                  onViewFullText: _openDocumentConsentFullText,
                ),
                const SizedBox(height: 12),
                _DocumentCard(
                  title: '신분증',
                  icon: Icons.badge_outlined,
                  imagePath: _docs.idCardImagePath,
                  footnote: _idCardRegistrationNotice,
                  enabled: _documentConsentAccepted && !_saving,
                  onRegister: () => _showPickSource(true),
                ),
                const SizedBox(height: 12),
                _DocumentCard(
                  title: '통장사본',
                  icon: Icons.account_balance_outlined,
                  imagePath: _docs.bankAccountImagePath,
                  footnote: '급여 지급 계좌 확인용으로 사용됩니다.',
                  enabled: _documentConsentAccepted && !_saving,
                  onRegister: () => _showPickSource(false),
                ),
                const SizedBox(height: 12),
                CorporateSurfaceCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.verified_outlined,
                      color: AppColors.primary.withValues(alpha: 0.95),
                    ),
                    title: const Text(
                      '자격·면허 사진 등록',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      '표준 자격 목록에서 선택 후 사진을 등록합니다.',
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: _documentConsentAccepted
                        ? () => Navigator.of(context).pushNamed(
                              AppRoutes.seekerMyCredentials,
                            )
                        : () => _showConsentRequiredSnackBar(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '등록된 서류는 채팅·메뉴의 「신분증 전송」「통장사본 전송」으로 '
                  '해당 공고 구인자에게 보낼 수 있습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
    );
  }
}

class _DocumentConsentCard extends StatelessWidget {
  const _DocumentConsentCard({
    required this.accepted,
    required this.onChanged,
    required this.onViewFullText,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onViewFullText;

  @override
  Widget build(BuildContext context) {
    return CorporateSurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '개인정보 수집·이용 동의 (필수)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary.withValues(alpha: 0.95),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '가입 시 동의와 별도로, 신분증·통장사본 등 민감정보를 '
            '등록·전송하기 전에 한 번 더 동의가 필요합니다.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: AppColors.textSecondary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: accepted,
            onChanged: (value) => onChanged(value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              '신분증·통장사본 수집·이용 및 구인자(채용 담당자) 제공에 동의합니다.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: onViewFullText,
              child: const Text('서류 수집·이용 동의 전문 보기'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({
    required this.title,
    required this.icon,
    required this.imagePath,
    this.footnote,
    this.enabled = true,
    this.onRegister,
  });

  final String title;
  final IconData icon;
  final String? imagePath;
  final String? footnote;
  final bool enabled;
  final VoidCallback? onRegister;

  @override
  Widget build(BuildContext context) {
    final hasImage = seekerDocumentHasImage(imagePath);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: CorporateSurfaceCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                if (hasImage)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      '등록됨',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
              ],
            ),
            if (footnote != null) ...[
              const SizedBox(height: 8),
              Text(
                footnote!,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.45,
                  color: AppColors.textSecondary.withValues(alpha: 0.92),
                ),
              ),
            ],
            if (hasImage) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: seekerDocumentImage(imagePath, height: 140),
              ),
            ],
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: enabled ? onRegister : null,
              icon: Icon(hasImage ? Icons.refresh_rounded : Icons.add_a_photo),
              label: Text(hasImage ? '다시 등록' : '등록하기'),
            ),
          ],
        ),
      ),
    );
  }
}
