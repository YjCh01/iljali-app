import 'package:flutter/material.dart';
import 'package:map/core/config/product_feature_flags.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/compliance/services/contact_entitlement_service.dart';
import 'package:map/core/constants/app_routes.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/features/corporate/data/datasources/corporate_applicant_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_applicant.dart';
import 'package:map/features/corporate/domain/usecases/get_corporate_applicants_usecase.dart';
import 'package:map/features/corporate/presentation/pages/corporate_applicant_resume_page.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_applicant_card.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';



/// 기업회원 3번 탭 — 지원자 관리

class CorporateApplicantsTab extends StatefulWidget {
  const CorporateApplicantsTab({
    super.key,
    this.focusJobPostId,
    this.focusJobTitle,
    this.onClearJobFilter,
  });

  final String? focusJobPostId;
  final String? focusJobTitle;
  final VoidCallback? onClearJobFilter;

  @override
  State<CorporateApplicantsTab> createState() => _CorporateApplicantsTabState();
}



class _CorporateApplicantsTabState extends State<CorporateApplicantsTab> {

  final _getApplicants = const GetCorporateApplicantsUseCase(

    CorporateApplicantLocalDataSourceImpl(),

  );



  List<CorporateApplicant> _applicants = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CorporateApplicantsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (HiringRefresh.consumeIfDirty()) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final applicants = await _getApplicants();
    if (!mounted) return;
    setState(() {
      _applicants = applicants;
      _loading = false;
    });
  }

  Future<bool> _blockIfContactSanctioned() async {
    final profile = AuthSession.instance.currentUser?.corporateProfile;
    if (profile == null) return true;
    final access =
        await ContactEntitlementService().evaluateWithUsage(profile);
    if (!mounted) return true;
    if (access.allowed) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(access.blockReason ?? '연락 기능을 사용할 수 없습니다.')),
    );
    return true;
  }

  Future<void> _openChat(CorporateApplicant applicant) async {
    final id = applicant.applicationId ?? applicant.id;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ApplicationChatPage(applicationId: id),
      ),
    );
    if (updated == true) await _load();
  }

  Future<void> _instantAccept(CorporateApplicant applicant) async {
    if (await _blockIfContactSanctioned()) return;
    final id = applicant.applicationId ?? applicant.id;
    final repo = await LocalHiringRepository.create();
    await repo.instantAccept(applicationId: id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${applicant.name}님을 출근 예정자로 확정했습니다.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
    await _load();
  }



  List<CorporateApplicant> get _visibleApplicants {
    final focusId = widget.focusJobPostId;
    if (focusId == null || focusId.isEmpty) return _applicants;
    return _applicants
        .where((a) => a.jobPostId == focusId || a.jobTitle == widget.focusJobTitle)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {

      return const ColoredBox(

        color: AppColors.background,

        child: Center(child: CircularProgressIndicator()),

      );

    }



    final visible = _visibleApplicants;
    final hasJobFilter = widget.focusJobPostId != null;
    final headerCount = (hasJobFilter ? 1 : 0) + 1;

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: headerCount + visible.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            if (index == 0) {
              return CorporateSurfaceCard(
                onTap: () => Navigator.of(context)
                    .pushNamed(AppRoutes.corporateTalentSearch),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_search_outlined,
                      color: AppColors.primary.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '인재 검색',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            '자격·지역·요일로 구직자를 찾고 활성 공고와 함께 제안하세요.',
                            style: TextStyle(fontSize: 12, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              );
            }

            if (hasJobFilter && index == 1) {
              return _JobFilterBanner(
                jobTitle: widget.focusJobTitle ?? '공고',
                applicantCount: visible.length,
                onClear: widget.onClearJobFilter,
              );
            }

            final applicantIndex = index - headerCount;
            if (applicantIndex < 0 || applicantIndex >= visible.length) {
              return const SizedBox.shrink();
            }
            final applicant = visible[applicantIndex];

            return CorporateApplicantCard(
              applicant: applicant,
              onTap: () {
                final id = applicant.applicationId ?? applicant.id;
                openCorporateApplicantResume(context, applicationId: id);
              },
              onChat: applicant.status == CorporateApplicantStatus.pending ||

                      applicant.status == CorporateApplicantStatus.chatting

                  ? () => _openChat(applicant)

                  : null,

              onInstantAccept: ProductFeatureFlags.isHiringCommissionEnabled &&

                  (applicant.status == CorporateApplicantStatus.pending ||

                      applicant.status == CorporateApplicantStatus.chatting)

                  ? () => _instantAccept(applicant)

                  : null,

            );

          },

        ),

      ),

    );

  }
}

class _JobFilterBanner extends StatelessWidget {
  const _JobFilterBanner({
    required this.jobTitle,
    required this.applicantCount,
    this.onClear,
  });

  final String jobTitle;
  final int applicantCount;
  final VoidCallback? onClear;

  static const _activeBg = Color(0xFFF3EEFF);
  static const _activeBorder = Color(0xFFD4C4FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _activeBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _activeBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.filter_alt_outlined,
            size: 18,
            color: AppColors.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '「$jobTitle」공고 지원자',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '이 공고에서 지원한 $applicantCount명을 보고 있습니다.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          if (onClear != null)
            TextButton(
              onPressed: onClear,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '전체',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}

