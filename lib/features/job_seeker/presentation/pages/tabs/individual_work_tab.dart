import 'package:flutter/material.dart';
import 'package:map/core/constants/app_colors.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/widgets/empty_state_card.dart';
import 'package:map/core/trust/company_rating_prompt_service.dart';
import 'package:map/core/trust/presentation/company_rating_dialog.dart';
import 'package:map/core/trust/presentation/employer_trust_section.dart';
import 'package:map/core/trust/local_company_rating_repository.dart';
import 'package:map/features/corporate/presentation/widgets/corporate_surface_card.dart';
import 'package:map/features/hiring/presentation/pages/shift_check_in_page.dart';

/// 구직자 4번 탭 — 근무·출근 (예정자 → 출근 체크)
class IndividualWorkTab extends StatefulWidget {
  const IndividualWorkTab({super.key, this.isActive = false});

  /// 활성 탭일 때만 자동 평가 프롬프트
  final bool isActive;

  @override
  State<IndividualWorkTab> createState() => _IndividualWorkTabState();
}

class _IndividualWorkTabState extends State<IndividualWorkTab> {
  List<HiringApplication> _shifts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant IndividualWorkTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) {
      _load();
      return;
    }
    if (widget.isActive && HiringRefresh.consumeIfDirty()) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final email = AuthSession.instance.currentUser?.email;
    if (email == null) {
      setState(() {
        _shifts = [];
        _loading = false;
      });
      return;
    }
    final repo = await LocalHiringRepository.create();
    final shifts = await repo.fetchScheduledForSeeker(email);
    if (!mounted) return;
    setState(() {
      _shifts = shifts;
      _loading = false;
    });
    await CompanyRatingPromptService.promptIfNeeded(
      context,
      shifts: shifts,
      isActive: widget.isActive,
    );
  }

  String _statusLabel(HiringApplication shift) {
    return switch (shift.status) {
      HiringApplicationStatus.scheduled => '출근 예정',
      HiringApplicationStatus.checkedIn => '출근 완료',
      HiringApplicationStatus.commissionPaid => '정산 완료',
      _ => shift.status.label,
    };
  }

  Future<void> _openCheckIn(HiringApplication shift) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ShiftCheckInPage(application: shift),
      ),
    );
    if (done == true) await _load();
  }

  Future<void> _rateEmployer(HiringApplication shift) async {
    await showCompanyRatingDialog(context, shift);
    if (mounted) await _load();
  }

  Future<bool> _canRateEmployer(HiringApplication shift) async {
    if (shift.companyKey == null || shift.companyKey!.isEmpty) return false;
    if (shift.status != HiringApplicationStatus.commissionPaid &&
        shift.status != HiringApplicationStatus.checkedIn) {
      return false;
    }
    final repo = await LocalCompanyRatingRepository.create();
    return !await repo.hasRated(shift.id);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: AppColors.background,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_shifts.isEmpty) {
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
                icon: Icons.event_available_outlined,
                title: '출근 예정 일정이 없습니다',
                message:
                    '푸시 알림을 받고 지원한 뒤\n기업과 채팅하거나 즉시 확정되면\n여기에 일정이 표시됩니다.',
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
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              '나의 근무 일정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            ..._shifts.map(
              (shift) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: CorporateSurfaceCard(
                  onTap: shift.status == HiringApplicationStatus.scheduled
                      ? () => _openCheckIn(shift)
                      : null,
                  child: Row(
                    children: [
                      Container(
                        width: 52,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primaryLight.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          shift.workDate != null
                              ? LocalHiringRepository.formatWorkDate(
                                  shift.workDate!,
                                )
                              : '--',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${shift.companyName} · ${shift.postTitle}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              shift.workSchedule,
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary
                                    .withValues(alpha: 0.95),
                              ),
                            ),
                            if (shift.companyKey != null) ...[
                              const SizedBox(height: 8),
                              EmployerTrustSection(
                                companyKey: shift.companyKey,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            _statusLabel(shift),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          if (shift.status ==
                              HiringApplicationStatus.scheduled)
                            TextButton(
                              onPressed: () => _openCheckIn(shift),
                              child: const Text('출근'),
                            ),
                          FutureBuilder<bool>(
                            future: _canRateEmployer(shift),
                            builder: (context, snapshot) {
                              if (snapshot.data != true) {
                                return const SizedBox.shrink();
                              }
                              return TextButton(
                                onPressed: () => _rateEmployer(shift),
                                child: const Text('고용주 평가'),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
