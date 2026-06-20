import 'package:flutter/foundation.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';
import 'package:map/features/corporate/domain/utils/job_post_limit_policy.dart';

abstract class CorporateJobPostLocalDataSource {
  Future<List<CorporateJobPost>> fetchJobPosts();
  Future<void> createJobPost(CorporateJobPost post);
  Future<void> updateJobPost(CorporateJobPost post);
  Future<bool> deleteJobPost(String id);
  Future<CorporateJobPost?> findById(String id);

  /// companyKey당 활성 공고 상한 — 초과 시 가장 오래된 공고 마감
  Future<List<String>> enforceActivePostLimit(String companyKey);
}

class CorporateJobPostLocalDataSourceImpl
    implements CorporateJobPostLocalDataSource {
  const CorporateJobPostLocalDataSourceImpl();

  static final List<CorporateJobPost> _posts = [];

  /// 테스트 격리용 — in-memory 공고 목록 초기화
  @visibleForTesting
  static void clearInMemoryStoreForTest() => _posts.clear();

  /// QC 서버 sync — 기존 in-memory 공고를 서버 스냅샷으로 교체
  static void replaceFromServer(List<CorporateJobPost> posts) {
    _posts
      ..clear()
      ..addAll(posts);
  }

  @override
  Future<List<CorporateJobPost>> fetchJobPosts() async =>
      List.unmodifiable(_posts);

  @override
  Future<void> createJobPost(CorporateJobPost post) async {
    final companyKey = post.registeredBy?.companyKey;
    if (companyKey != null && companyKey.isNotEmpty) {
      await enforceActivePostLimit(companyKey);
    }
    _posts.insert(0, post);
  }

  @override
  Future<List<String>> enforceActivePostLimit(String companyKey) async {
    final toClose = JobPostLimitPolicy.idsToAutoClose(
      posts: _posts,
      companyKey: companyKey,
    );
    for (final id in toClose) {
      final index = _posts.indexWhere((item) => item.id == id);
      if (index == -1) continue;
      _posts[index] = _posts[index].copyWith(
        status: CorporateJobPostStatus.closed,
      );
    }
    return toClose;
  }

  @override
  Future<void> updateJobPost(CorporateJobPost post) async {
    final index = _posts.indexWhere((item) => item.id == post.id);
    if (index == -1) return;
    _posts[index] = post;
  }

  @override
  Future<bool> deleteJobPost(String id) async {
    final index = _posts.indexWhere((item) => item.id == id);
    if (index == -1) return false;
    _posts.removeAt(index);
    return true;
  }

  @override
  Future<CorporateJobPost?> findById(String id) async {
    for (final post in _posts) {
      if (post.id == id) return post;
    }
    return null;
  }
}
