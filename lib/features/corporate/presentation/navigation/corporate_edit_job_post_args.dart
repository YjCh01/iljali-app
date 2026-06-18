import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// [CorporateEditJobPostPage] 라우트 인자
class CorporateEditJobPostArgs {
  const CorporateEditJobPostArgs({
    required this.post,
    this.asCopy = false,
  });

  final CorporateJobPost post;
  final bool asCopy;
}
