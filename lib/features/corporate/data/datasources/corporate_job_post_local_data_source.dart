import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

abstract class CorporateJobPostLocalDataSource {
  Future<List<CorporateJobPost>> fetchJobPosts();
  Future<void> createJobPost(CorporateJobPost post);
  Future<void> updateJobPost(CorporateJobPost post);
  Future<bool> deleteJobPost(String id);
  Future<CorporateJobPost?> findById(String id);
}

class CorporateJobPostLocalDataSourceImpl
    implements CorporateJobPostLocalDataSource {
  const CorporateJobPostLocalDataSourceImpl();

  static final List<CorporateJobPost> _posts = [];

  @override
  Future<List<CorporateJobPost>> fetchJobPosts() async =>
      List.unmodifiable(_posts);

  @override
  Future<void> createJobPost(CorporateJobPost post) async {
    _posts.insert(0, post);
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
