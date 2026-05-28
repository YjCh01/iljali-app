import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/empty_state_card.dart';
import 'package:map/core/widgets/mvp_feedback.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/job_seeker/data/repositories/job_application_repository.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_application_card.dart';
import 'package:map/features/job_seeker/domain/entities/job_application.dart';

/// 구직자 3번 탭 — 내 지원 현황 (↔ 기업 지원자 관리)
class IndividualApplicationsTab extends StatefulWidget {
  const IndividualApplicationsTab({super.key});

  @override
  State<IndividualApplicationsTab> createState() =>
      _IndividualApplicationsTabState();
}

class _IndividualApplicationsTabState extends State<IndividualApplicationsTab> {
  static final _dateFormat = DateFormat('yyyy.MM.dd');

  List<JobApplication> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant IndividualApplicationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final email = AuthSession.instance.currentUser?.email;
    final repo = await JobApplicationRepository.create(email);
    final hiringRepo = await LocalHiringRepository.create();
    final hiringItems = email == null
        ? <HiringApplication>[]
        : await hiringRepo.fetchForSeeker(email);
    final items = repo == null ? <JobApplication>[] : await repo.fetchAll();
    final posts = await const CorporateJobPostLocalDataSourceImpl().fetchJobPosts();
    final postCompanyKeys = {
      for (final p in posts)
        if (p.registeredBy != null) p.id: p.registeredBy!.companyKey,
    };

    final merged = items.map((item) {
      HiringApplication? hiring;
      for (final h in hiringItems) {
        if (h.postId == item.postId) {
          hiring = h;
          break;
        }
      }
      final companyKey = hiring?.companyKey ??
          item.companyKey ??
          postCompanyKeys[item.postId];
      if (hiring == null) {
        return JobApplication(
          postId: item.postId,
          title: item.title,
          company: item.company,
          appliedAt: item.appliedAt,
          status: item.status,
          companyKey: companyKey,
        );
      }
      return JobApplication(
        postId: item.postId,
        title: item.title,
        company: item.company,
        appliedAt: item.appliedAt,
        status: hiring.status.label,
        companyKey: companyKey,
      );
    }).toList();

    if (!mounted) return;
    setState(() {
      _items = merged;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_items.isEmpty) {
      return ColoredBox(
        color: AppColors.background,
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.primary,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 120),
              EmptyStateCard(
                icon: Icons.description_outlined,
                title: '아직 지원한 공고가 없습니다',
                message: '지도나 공고 탭에서 마음에 드는 일자리에\n지원해 보세요.',
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.background,
      child: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final item = _items[index];
            return SeekerApplicationCard(
              item: item,
              dateFormat: _dateFormat,
              onTap: () => showMvpInfoSnackBar(
                context,
                '지원 상세',
                hint: '현재는 접수 상태만 확인할 수 있습니다.',
              ),
            );
          },
        ),
      ),
    );
  }
}

