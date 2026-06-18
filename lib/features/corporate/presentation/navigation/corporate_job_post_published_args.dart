import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/entities/workplace_address.dart';

/// [CorporateJobPostPublishedPage] 라우트 인자
class CorporateJobPostPublishedArgs {
  const CorporateJobPostPublishedArgs({
    required this.post,
    required this.workplace,
  });

  final CorporateJobPost post;
  final WorkplaceAddress workplace;
}
