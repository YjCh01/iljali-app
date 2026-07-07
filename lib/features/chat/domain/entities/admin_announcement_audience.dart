import 'package:map/core/session/member_type.dart';

/// 운영 공지 수신 대상
enum AdminAnnouncementAudience {
  all,
  seeker,
  corporate,
}

extension AdminAnnouncementAudienceX on AdminAnnouncementAudience {
  String get apiValue => switch (this) {
        AdminAnnouncementAudience.all => 'all',
        AdminAnnouncementAudience.seeker => 'seeker',
        AdminAnnouncementAudience.corporate => 'corporate',
      };

  String get label => switch (this) {
        AdminAnnouncementAudience.all => '전체',
        AdminAnnouncementAudience.seeker => '개인회원',
        AdminAnnouncementAudience.corporate => '기업회원',
      };

  static AdminAnnouncementAudience fromApi(String? raw) {
    switch ((raw ?? 'all').trim().toLowerCase()) {
      case 'seeker':
      case 'individual':
        return AdminAnnouncementAudience.seeker;
      case 'corporate':
      case 'employer':
        return AdminAnnouncementAudience.corporate;
      default:
        return AdminAnnouncementAudience.all;
    }
  }

  bool visibleForMemberType(MemberType? memberType) {
    if (this == AdminAnnouncementAudience.all) return true;
    if (memberType == null) return false;
    return switch (this) {
      AdminAnnouncementAudience.seeker =>
        memberType == MemberType.individual,
      AdminAnnouncementAudience.corporate =>
        memberType == MemberType.corporate,
      AdminAnnouncementAudience.all => true,
    };
  }
}
