import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/corporate_member_profile.dart';
import 'package:map/features/corporate/domain/entities/job_post_payment_record.dart';

/// 내부 결재라인 보고서 데이터
class InternalApprovalReport {
  const InternalApprovalReport({
    required this.profile,
    required this.post,
    this.paymentRecord,
  });

  final CorporateMemberProfile profile;
  final CorporateJobPost post;
  final JobPostPaymentRecord? paymentRecord;

  bool get hasPayment => paymentRecord != null;
}
