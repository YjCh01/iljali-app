import 'package:flutter/material.dart';
import 'package:map/core/hiring/local_hiring_repository.dart';
import 'package:map/core/session/auth_session.dart';
import 'package:map/core/session/member_type.dart';
import 'package:map/features/chat/domain/services/chat_access_policy.dart';
import 'package:map/features/hiring/presentation/pages/application_chat_page.dart';
import 'package:map/features/hiring/presentation/widgets/seeker_attendance_lock_dialog.dart';
import 'package:map/features/job_seeker/domain/entities/job_map_pin.dart';
import 'package:map/features/job_seeker/presentation/utils/seeker_shell_access.dart';
import 'package:map/features/job_seeker/presentation/widgets/seeker_login_prompt_sheet.dart';

/// 공고 상세 — 지원 전 기업 문의 채팅
class JobPostInquiryService {
  const JobPostInquiryService();

  static String maskPhone(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 10) {
      return '${digits.substring(0, 3)}-****-${digits.substring(digits.length - 4)}';
    }
    return '미등록';
  }

  Future<bool> openInquiryChat(BuildContext context, JobMapPin pin) async {
    if (!SeekerShellAccess.isSignedInSeeker) {
      await SeekerLoginPromptSheet.show(
        context,
        message: '문의하려면 개인회원 로그인 또는 회원가입이 필요합니다.',
      );
      return false;
    }

    final user = AuthSession.instance.currentUser;
    if (user == null || user.memberType != MemberType.individual) {
      return false;
    }

    if (!await ensureSeekerAttendanceAccess(context, user.email)) {
      return false;
    }
    if (!context.mounted) return false;

    final policy = ChatAccessPolicy.evaluatePair(
      requester: MemberType.individual,
      peer: MemberType.corporate,
    );
    if (!policy.allowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(policy.message ?? '채팅 접근이 제한되었습니다.')),
      );
      return false;
    }

    final post = pin.post;
    final repo = await LocalHiringRepository.create();
    final application = await repo.openInquiry(
      postId: post.id,
      postTitle: post.title,
      companyName: pin.companyName,
      seekerEmail: user.email,
      seekerName: user.name,
      seekerPhoneMasked: maskPhone(user.phone),
      companyKey: post.registeredBy?.companyKey,
      recruiterEmail: post.recruiterEmail,
      branchId: post.branchId,
      branchName: post.branchName,
      workplaceLatitude: post.workplaceLatitude,
      workplaceLongitude: post.workplaceLongitude,
    );

    if (!context.mounted) return false;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ApplicationChatPage(applicationId: application.id),
      ),
    );
    return true;
  }
}
