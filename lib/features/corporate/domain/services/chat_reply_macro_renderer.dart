import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/features/corporate/domain/entities/chat_reply_macro.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';

/// 매크로 본문의 `{공고명}` 등 플레이스홀더 치환
class ChatReplyMacroRenderer {
  const ChatReplyMacroRenderer();

  String renderBody({
    required ChatReplyMacro macro,
    required HiringApplication application,
    CorporateJobPost? jobPost,
    CorporateMemberProfile? profile,
  }) {
    final workplace = _workplaceLabel(application, jobPost, profile);
    final description = _jobDescription(jobPost);
    final contact = profile?.contactPersonName.trim();
    final contactLabel =
        contact != null && contact.isNotEmpty ? contact : '채용 담당';

    return macro.body
        .replaceAll('{공고명}', application.postTitle)
        .replaceAll('{회사명}', application.companyName)
        .replaceAll('{근무지}', workplace)
        .replaceAll('{근무일정}', application.workSchedule)
        .replaceAll('{업무내용}', description)
        .replaceAll('{담당자}', contactLabel);
  }

  String _workplaceLabel(
    HiringApplication application,
    CorporateJobPost? jobPost,
    CorporateMemberProfile? profile,
  ) {
    final branch = application.branchName?.trim();
    if (branch != null && branch.isNotEmpty) return branch;

    final warehouse = jobPost?.warehouseName.trim();
    if (warehouse != null && warehouse.isNotEmpty) return warehouse;

    final headOffice = profile?.businessHeadOfficeAddress?.trim();
    if (headOffice != null && headOffice.isNotEmpty) return headOffice;

    return '공고에 안내된 근무지';
  }

  String _jobDescription(CorporateJobPost? jobPost) {
    if (jobPost == null) {
      return '공고 상세 페이지의 업무 안내를 참고해 주세요.';
    }
    final description = jobPost.jobDescription.trim();
    if (description.isNotEmpty) return description;

    final summary = jobPost.summary.trim();
    if (summary.isNotEmpty) return summary;

    return '공고 상세 페이지의 업무 안내를 참고해 주세요.';
  }
}
