import 'package:flutter/material.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/core/hiring/hiring_refresh.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/hiring/selected_shift_dates.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/features/commute/data/repositories/commute_route_repository.dart';
import 'package:map/features/commute/data/repositories/shuttle_booking_repository.dart';
import 'package:map/features/commute/domain/entities/shuttle_booking.dart';
import 'package:map/features/commute/domain/services/shuttle_reminder_service.dart';
import 'package:map/features/commute/domain/utils/shuttle_route_visibility.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/corporate/data/datasources/corporate_job_post_local_data_source.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/work_schedule_negotiable.dart';
import 'package:map/features/hiring/data/repositories/job_proposal_repository.dart';
import 'package:map/features/hiring/domain/entities/job_proposal.dart';
import 'package:map/features/job_seeker/data/repositories/job_application_repository.dart';
import 'package:map/features/job_seeker/domain/entities/job_application.dart';
import 'package:map/features/job_seeker/domain/entities/resume_item_kind.dart';
import 'package:map/features/job_seeker/domain/entities/seeker_resume_content.dart';
import 'package:map/features/hiring/presentation/widgets/seeker_attendance_lock_dialog.dart';
import 'package:map/features/job_seeker/presentation/widgets/job_apply_flow_sheet.dart';
import 'package:map/features/commute/domain/entities/commute_route.dart';
import 'package:map/features/job_seeker/presentation/widgets/credential_apply_dialog.dart';
import 'package:map/features/job_seeker/presentation/widgets/resume_disclosure_dialog.dart';

/// 구직자 — 받은 채용 제안 수락·거절
abstract final class JobProposalAcceptService {
  static Future<bool> accept({
    required BuildContext context,
    required JobProposal proposal,
    VoidCallback? onApplied,
  }) async {
    final user = AuthSession.instance.currentUser;
    if (user == null) return false;

    if (user.memberType != MemberType.individual) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '기업회원 계정에서는 지원할 수 없습니다. '
              '개인회원으로 로그인해 주세요.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final post = await const CorporateJobPostLocalDataSourceImpl()
        .findById(proposal.postId);
    if (post == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('연결된 공고를 찾을 수 없습니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    final hiringRepo = await LocalHiringRepository.create();
    if (await hiringRepo.hasApplied(proposal.postId, user.email)) {
      final proposalRepo = await JobProposalRepository.create();
      await proposalRepo.updateStatus(
        proposalId: proposal.id,
        status: JobProposalStatus.accepted,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('이미 「${proposal.postTitle}」에 지원 중입니다.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return false;
    }

    if (!await ensureSeekerAttendanceAccess(context, user.email)) {
      return false;
    }
    if (!context.mounted) return false;

    CommuteRoute? shuttleRoute;
    if (post.commuteRouteId != null) {
      final routeRepo = await CommuteRouteRepository.create();
      final loaded = await routeRepo.findById(post.commuteRouteId!);
      if (loaded != null &&
          ShuttleRouteVisibility.hasSeekerVisibleStops(loaded)) {
        shuttleRoute = ShuttleRouteVisibility.forSeekerDisplay(loaded);
      }
    }

    if (!context.mounted) return false;

    final flowResult = await showJobApplyFlowSheet(
      context,
      postTitle: post.title,
      workSchedule: post.workSchedule,
      workerCategory: post.effectiveWorkerCategory,
      hasShuttle: shuttleRoute != null,
      workScheduleNegotiable: post.workScheduleNegotiable ||
          WorkScheduleNegotiable.isLabel(post.workSchedule),
      shuttleRoute: shuttleRoute,
    );
    if (flowResult == null || !context.mounted) return false;

    if (post.requiredCredentialIds.isNotEmpty) {
      final proceed = await showRequiredCredentialsApplyDialog(
        context,
        credentialIds: post.requiredCredentialIds,
      );
      if (!proceed || !context.mounted) return false;
    }

    final shuttleSel = flowResult.shuttleSelection;
    final shiftDateIso = flowResult.scheduleNegotiable
        ? ''
        : SelectedShiftDates.encode(flowResult.selectedDates);
    String? bookingId;
    if (shuttleSel != null && shuttleRoute != null) {
      final shuttleDay = flowResult.primaryDate ?? DateTime.now();
      final shuttleDateIso = SelectedShiftDates.encode([shuttleDay]);
      bookingId = 'book_${DateTime.now().millisecondsSinceEpoch}';
      final booking = ShuttleBooking(
        id: bookingId,
        seekerEmail: user.email,
        postId: post.id,
        routeId: shuttleRoute.id,
        stopId: shuttleSel.stop.id,
        stopLabel: shuttleSel.stop.label,
        pickupTime: shuttleSel.pickupTime,
        shiftDate: shuttleDateIso,
        createdAt: DateTime.now(),
      );
      final bookingRepo = await ShuttleBookingRepository.create();
      await bookingRepo.save(booking);
      final reminderService = await ShuttleReminderService.create();
      await reminderService.scheduleForBooking(booking);
    }

    final phone = user.phone ?? '010-0000-0000';

    final requiredItems = post.requiredResumeItems;
    var disclosedItems = const <ResumeItemKind>[];
    if (requiredItems.isNotEmpty) {
      final profile = user.seekerProfile;
      final resume = profile?.resume ?? const SeekerResumeContent();
      final disclosed = await showResumeDisclosureFlow(
        context,
        requiredItems: requiredItems,
        resume: resume,
        profile: profile,
      );
      if (disclosed == null || !context.mounted) return false;
      disclosedItems = disclosed.toList();
    }

    await hiringRepo.submitApplication(
      postId: post.id,
      postTitle: post.title,
      companyName: proposal.companyName,
      companyKey: post.registeredBy?.companyKey,
      recruiterEmail: post.recruiterEmail,
      branchId: post.branchId,
      branchName: post.branchName,
      workplaceLatitude: post.workplaceLatitude,
      workplaceLongitude: post.workplaceLongitude,
      seekerEmail: user.email,
      seekerName: user.name,
      seekerPhoneMasked: phone,
      workSchedule: post.workSchedule,
      suggestedWorkDate: flowResult.primaryDate,
      hourlyWageText: post.hourlyWage,
      employmentType: post.employmentType,
      selectedShiftDate: shiftDateIso,
      shiftSlot: flowResult.shiftSlot,
      shuttleBookingId: bookingId,
      preferredStopId: shuttleSel?.stop.id,
      disclosedResumeItems: disclosedItems,
      requiredCredentialIds: post.requiredCredentialIds,
    );

    final appRepo = await JobApplicationRepository.create(user.email);
    if (appRepo != null) {
      await appRepo.add(
        JobApplication(
          postId: post.id,
          title: post.title,
          company: proposal.companyName,
          appliedAt: DateTime.now(),
          status: HiringApplicationStatus.applied.label,
          companyKey: post.registeredBy?.companyKey,
          selectedShiftDate: shiftDateIso,
          shiftSlot: flowResult.shiftSlot,
          shuttleBookingId: bookingId,
          preferredStopId: shuttleSel?.stop.id,
        ),
      );
    }

    final proposalRepo = await JobProposalRepository.create();
    await proposalRepo.updateStatus(
      proposalId: proposal.id,
      status: JobProposalStatus.accepted,
    );
    HiringRefresh.markUpdated();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('「${proposal.postTitle}」 제안을 수락해 지원했습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
    onApplied?.call();
    return true;
  }

  static Future<void> decline(JobProposal proposal) async {
    final repo = await JobProposalRepository.create();
    await repo.updateStatus(
      proposalId: proposal.id,
      status: JobProposalStatus.declined,
    );
  }
}
