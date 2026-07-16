import 'package:flutter/material.dart';
import 'package:map/core/api/iljari_api_client.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/widgets/app_back_button.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_applicant.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_snapshot.dart';
import 'package:map/features/job_seeker/presentation/pages/seeker_resume_detail_page.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_resume_grid_summary.dart';

/// 구인자 — 지원자 이력서 (그리드 요약 → 상세보기)
class CorporateApplicantResumePage extends StatefulWidget {
  const CorporateApplicantResumePage({
    super.key,
    required this.applicationId,
  });

  final String applicationId;

  @override
  State<CorporateApplicantResumePage> createState() =>
      _CorporateApplicantResumePageState();
}

Future<void> openCorporateApplicantResume(
  BuildContext context, {
  required String applicationId,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => CorporateApplicantResumePage(
        applicationId: applicationId,
      ),
    ),
  );
}

class _CorporateApplicantResumePageState
    extends State<CorporateApplicantResumePage> {
  HiringApplication? _application;
  List<String> _postRequiredCredentialIds = const [];
  List<Map<String, dynamic>>? _serverCredentialHoldings;
  bool? _serverCanViewDocuments;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = await LocalHiringRepository.create();
    final app = await repo.findById(widget.applicationId);
    var requiredIds = app?.requiredCredentialIds ?? const <String>[];
    if (app != null && requiredIds.isEmpty) {
      final post = await const CorporateJobPostLocalDataSourceImpl()
          .findById(app.postId);
      requiredIds = post?.requiredCredentialIds ?? const [];
    }

    List<Map<String, dynamic>>? holdings;
    bool? canViewDocuments;
    if (app != null) {
      try {
        final response =
            await IljariApiClient().fetchApplicantCredentials(app.id);
        final rawHoldings = response['holdings'];
        if (rawHoldings is List) {
          holdings = rawHoldings
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList();
        }
        canViewDocuments = response['can_view_documents'] as bool?;
      } on Object {
        // 오프라인 — 기기 로컬 프로필 폴백으로 진행.
      }
    }

    if (!mounted) return;
    setState(() {
      _application = app;
      _postRequiredCredentialIds = requiredIds;
      _serverCredentialHoldings = holdings;
      _serverCanViewDocuments = canViewDocuments;
      _loading = false;
    });
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
        title: const Text('지원자 이력서'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _application == null
              ? _NotFound(onBack: () => Navigator.of(context).pop())
              : _ResumeGridView(
                  application: _application!,
                  postRequiredCredentialIds: _postRequiredCredentialIds,
                  serverCredentialHoldings: _serverCredentialHoldings,
                  serverCanViewDocuments: _serverCanViewDocuments,
                ),
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('지원 정보를 찾을 수 없습니다.'),
          const SizedBox(height: 12),
          TextButton(onPressed: onBack, child: const Text('돌아가기')),
        ],
      ),
    );
  }
}

class _ResumeGridView extends StatelessWidget {
  const _ResumeGridView({
    required this.application,
    required this.postRequiredCredentialIds,
    this.serverCredentialHoldings,
    this.serverCanViewDocuments,
  });

  final HiringApplication application;
  final List<String> postRequiredCredentialIds;
  final List<Map<String, dynamic>>? serverCredentialHoldings;
  final bool? serverCanViewDocuments;

  @override
  Widget build(BuildContext context) {
    final snapshot = SeekerResumeSnapshot.fromApplication(
      application,
      postRequiredCredentialIds: postRequiredCredentialIds,
      serverCredentialHoldings: serverCredentialHoldings,
      serverCanViewDocuments: serverCanViewDocuments,
    );
    final status = _mapStatus(application.status);
    final heldCount = snapshot.heldCredentialCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        SeekerResumeGridSummary(
          snapshot: snapshot,
          subtitle: application.postTitle,
          trailing: _StatusBadge(status: status),
          resumeCounts: ResumeItemKind.values.map((kind) {
            if (kind == ResumeItemKind.license ||
                kind == ResumeItemKind.certification) {
              return heldCount;
            }
            return snapshot.visibleResume.countFor(kind);
          }).toList(),
        ),
        const SizedBox(height: 12),
        Text(
          '지원 ${LocalHiringRepository.formatRelativeTime(application.appliedAt)}',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary.withValues(alpha: 0.9),
          ),
        ),
        if (application.seekerNoShowCount > 0) ...[
          const SizedBox(height: 8),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '이 구직자는 다른 기업 포함 누적 노쇼 ${application.seekerNoShowCount}회',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC62828),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => openSeekerResumeDetail(
              context,
              snapshot: snapshot,
              title: '지원자 이력서 상세',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '상세보기',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }

  CorporateApplicantStatus _mapStatus(HiringApplicationStatus status) =>
      switch (status) {
        HiringApplicationStatus.inquiry =>
          CorporateApplicantStatus.chatting,
        HiringApplicationStatus.applied => CorporateApplicantStatus.pending,
        HiringApplicationStatus.chatting => CorporateApplicantStatus.chatting,
        HiringApplicationStatus.scheduled => CorporateApplicantStatus.scheduled,
        HiringApplicationStatus.checkedIn => CorporateApplicantStatus.checkedIn,
        HiringApplicationStatus.commissionPaid =>
          CorporateApplicantStatus.commissionPaid,
        HiringApplicationStatus.rejected => CorporateApplicantStatus.rejected,
        HiringApplicationStatus.noShow => CorporateApplicantStatus.rejected,
      };
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final CorporateApplicantStatus status;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (status) {
      CorporateApplicantStatus.pending => (
          AppColors.primaryLight.withValues(alpha: 0.28),
          AppColors.primary,
        ),
      CorporateApplicantStatus.chatting => (
          const Color(0xFFFFF8E1),
          const Color(0xFFF57F17),
        ),
      CorporateApplicantStatus.scheduled => (
          const Color(0xFFE3F2FD),
          const Color(0xFF1565C0),
        ),
      CorporateApplicantStatus.checkedIn => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
        ),
      CorporateApplicantStatus.commissionPaid => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
        ),
      CorporateApplicantStatus.rejected => (
          AppColors.background,
          AppColors.textSecondary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
