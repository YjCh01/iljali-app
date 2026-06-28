import 'package:map/core/session/auth_session.dart';
import 'package:map/features/corporate/domain/entities/corporate_job_post.dart';

/// 기업 공고 소유·목록 범위 — 타사 공고 노출·수정 차단
abstract final class CorporateJobPostScope {
  static String normalizeCompanyKey(String raw) =>
      raw.replaceAll(RegExp(r'[^0-9]'), '');

  static String? companyKeyOf(CorporateJobPost post) {
    final fromProfile = post.registeredBy?.companyKey;
    if (fromProfile != null && fromProfile.isNotEmpty) {
      return normalizeCompanyKey(fromProfile);
    }
    return null;
  }

  static bool belongsToCompany(CorporateJobPost post, String companyKey) {
    final owner = companyKeyOf(post);
    final viewer = normalizeCompanyKey(companyKey);
    if (owner == null || owner.isEmpty || viewer.isEmpty) return false;
    return owner == viewer;
  }

  static List<CorporateJobPost> filterForCompany(
    List<CorporateJobPost> posts,
    String companyKey,
  ) {
    final viewer = normalizeCompanyKey(companyKey);
    if (viewer.isEmpty) return const [];
    return posts
        .where((post) => belongsToCompany(post, viewer))
        .toList(growable: false);
  }

  static String? currentOwnerCompanyKey() =>
      AuthSession.instance.currentUser?.corporateProfile?.companyKey;
}

class CorporateJobPostAccessDenied implements Exception {
  CorporateJobPostAccessDenied([this.message = '다른 기업의 공고는 변경할 수 없습니다.']);
  final String message;

  @override
  String toString() => message;
}
