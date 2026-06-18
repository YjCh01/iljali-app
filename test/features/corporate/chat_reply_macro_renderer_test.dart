import 'package:flutter_test/flutter_test.dart';
import 'package:map/core/hiring/hiring_application.dart';
import 'package:map/core/hiring/hiring_application_status.dart';
import 'package:map/features/corporate/domain/entities/chat_reply_macro.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/worker_category.dart';
import 'package:map/features/corporate/domain/services/chat_reply_macro_renderer.dart';

void main() {
  const renderer = ChatReplyMacroRenderer();
  final postedAt = DateTime(2026, 1, 1);

  final application = HiringApplication(
    id: 'app-1',
    postId: 'post-1',
    postTitle: '야간 보조',
    companyName: '강남물류',
    seekerEmail: 'a@b.com',
    seekerName: '홍길동',
    seekerPhoneMasked: '010-****-1234',
    appliedAt: DateTime(2026, 1, 1),
    status: HiringApplicationStatus.chatting,
    workSchedule: '월~금 09:00~18:00',
    branchName: '수원센터',
  );

  final jobPost = CorporateJobPost(
    id: 'post-1',
    title: '야간 보조',
    warehouseName: '수원센터',
    hourlyWage: '12000',
    workSchedule: '월~금 09:00~18:00',
    summary: '입출고 보조',
    jobDescription: '상·하차 및 분류 보조 업무입니다.',
    status: CorporateJobPostStatus.recruiting,
    applicantCount: 1,
    postedAt: postedAt,
  );

  test('renders default hiring macro with placeholders', () {
    final macro = ChatReplyMacroDefaults.items.first;
    final text = renderer.renderBody(
      macro: macro,
      application: application,
      jobPost: jobPost,
    );

    expect(text, contains('야간 보조'));
    expect(text, contains('모집 중'));
  });

  test('renders workplace and job detail macros', () {
    final workplace = renderer.renderBody(
      macro: ChatReplyMacroDefaults.items[1],
      application: application,
      jobPost: jobPost,
    );
    final detail = renderer.renderBody(
      macro: ChatReplyMacroDefaults.items[2],
      application: application,
      jobPost: jobPost,
    );

    expect(workplace, contains('수원센터'));
    expect(workplace, contains('월~금 09:00~18:00'));
    expect(detail, contains('상·하차 및 분류 보조 업무입니다.'));
  });
}
