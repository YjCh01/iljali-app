import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 사업자번호(companyKey)당 동시 활성 공고 상한
abstract final class JobPostLimitPolicy {
  static const maxConcurrentActivePosts = 10;

  static bool isActivePost(CorporateJobPost post) =>
      post.isActiveForSeekers &&
      post.status != CorporateJobPostStatus.closed;

  static List<CorporateJobPost> activePostsForCompany(
    Iterable<CorporateJobPost> posts,
    String companyKey,
  ) {
    return posts
        .where(
          (p) =>
              p.registeredBy?.companyKey == companyKey && isActivePost(p),
        )
        .toList()
      ..sort((a, b) => a.postedAt.compareTo(b.postedAt));
  }

  /// 새 공고 1건 등록 전 — 초과분은 가장 오래된 활성 공고를 마감 처리
  static List<String> idsToAutoClose({
    required Iterable<CorporateJobPost> posts,
    required String companyKey,
    int maxActive = maxConcurrentActivePosts,
  }) {
    final active = activePostsForCompany(posts, companyKey);
    if (active.length < maxActive) return const [];
    final overflow = active.length - maxActive + 1;
    return active.take(overflow).map((p) => p.id).toList();
  }
}
